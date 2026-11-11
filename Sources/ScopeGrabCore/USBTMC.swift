import Foundation
import IOKit
import IOUSBHost

// USBTMC message framing (USB Test & Measurement Class, rev 1.0, §3.2).
// Every bulk message starts with a 12-byte header: MsgID, bTag, ~bTag, 0,
// TransferSize (little-endian u32), attributes, then 3 bytes that depend on MsgID.

enum USBTMCMsg: UInt8 {
    case devDepMsgOut = 1      // host -> device: command bytes follow
    case requestDevDepMsgIn = 2 // host -> device: "send me up to N bytes"; device answers with MsgID 2
}

/// Builds a bulk-out header. `eom` marks the last chunk of a command.
func usbtmcHeader(_ msg: USBTMCMsg, tag: UInt8, size: Int, eom: Bool = false) -> [UInt8] {
    let s = UInt32(size)
    return [msg.rawValue, tag, ~tag, 0,
            UInt8(s & 0xff), UInt8(s >> 8 & 0xff), UInt8(s >> 16 & 0xff), UInt8(s >> 24 & 0xff),
            eom ? 1 : 0, 0, 0, 0]
}

/// Parses the header of a bulk-in reply: the payload size and whether it ends the message.
func parseInHeader(_ b: some Collection<UInt8>, tag: UInt8) throws -> (size: Int, eom: Bool) {
    let h = Array(b.prefix(12))
    guard h.count == 12, h[0] == USBTMCMsg.requestDevDepMsgIn.rawValue, h[1] == tag, h[2] == ~tag else {
        throw ScopeError.protocolError("unexpected USB reply header")
    }
    let size = Int(h[4]) | Int(h[5]) << 8 | Int(h[6]) << 16 | Int(h[7]) << 24
    return (size, h[8] & 1 == 1)
}

public enum ScopeError: Error, LocalizedError, Equatable {
    case notFound
    case protocolError(String)
    case usb(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            "scope not found on USB. Check the cable, and that Utility → IO Setting → USB Device is set to Computer"
        case .protocolError(let s): s
        case .usb(let s): "USB error: \(s)"
        }
    }
}

/// The Rigol DS2000A over USBTMC (vendor 0x1AB1, product 0x04B0), through Apple's
/// IOUSBHost framework. macOS has no driver for this interface, so user space can open it.
/// Calls block; run them off the main thread.
public final class Scope {
    static let vendorID = 0x1AB1
    static let productID = 0x04B0

    private let interface: IOUSBHostInterface
    private let bulkOut: IOUSBHostPipe
    private let bulkIn: IOUSBHostPipe
    private var tag: UInt8 = 0
    private let timeout: TimeInterval

    /// Opens the scope's USBTMC interface. Throws `.notFound` if no scope is attached.
    public init(timeout: TimeInterval = 5) throws {
        let match = IOServiceMatching("IOUSBHostInterface") as NSMutableDictionary
        match["IOPropertyMatch"] = ["idVendor": Self.vendorID, "idProduct": Self.productID, "bInterfaceNumber": 0]
        let service = IOServiceGetMatchingService(kIOMainPortDefault, match as CFDictionary)
        guard service != 0 else { throw ScopeError.notFound }
        defer { IOObjectRelease(service) }

        do {
            interface = try IOUSBHostInterface(__ioService: service, options: [], queue: nil, interestHandler: nil)
        } catch {
            throw ScopeError.usb("can't open the scope's USB interface (\(error.localizedDescription))")
        }
        var outPipe: IOUSBHostPipe?, inPipe: IOUSBHostPipe?
        for address in [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86] {
            guard let pipe = try? interface.copyPipe(withAddress: address),
                  pipe.descriptors.pointee.descriptor.bmAttributes & 3 == 2 else { continue } // bulk only
            if address & 0x80 != 0 { inPipe = inPipe ?? pipe } else { outPipe = outPipe ?? pipe }
        }
        guard let outPipe, let inPipe else {
            interface.destroy()
            throw ScopeError.protocolError("the scope's USB interface has no bulk endpoints")
        }
        bulkOut = outPipe
        bulkIn = inPipe
        self.timeout = timeout
    }

    deinit { interface.destroy() }

    /// Opens the scope, runs `body`, and closes it again.
    public static func session<T>(_ body: (Scope) throws -> T) throws -> T {
        try body(Scope())
    }

    private func nextTag() -> UInt8 {
        tag = tag == 255 ? 1 : tag + 1 // bTag must not be 0
        return tag
    }

    private func transfer(_ pipe: IOUSBHostPipe, _ data: NSMutableData) throws -> Int {
        var n: UInt = 0
        do {
            try pipe.__sendIORequest(with: data, bytesTransferred: &n, completionTimeout: timeout)
        } catch {
            throw ScopeError.usb(error.localizedDescription)
        }
        return Int(n)
    }

    public func send(_ command: String) throws {
        var payload = Array((command + "\n").utf8)
        var message = usbtmcHeader(.devDepMsgOut, tag: nextTag(), size: payload.count, eom: true)
        while payload.count % 4 != 0 { payload.append(0) } // pad to a 4-byte boundary
        message += payload
        _ = try transfer(bulkOut, NSMutableData(bytes: message, length: message.count))
    }

    /// Reads one complete reply, however many USBTMC transfers it spans.
    public func read(maxSize: Int = 4 << 20) throws -> Data {
        var out = Data()
        let buffer = NSMutableData(length: 1 << 20)!
        let bytes = buffer.bytes.assumingMemoryBound(to: UInt8.self)
        var eom = false
        while !eom {
            let t = nextTag()
            let request = usbtmcHeader(.requestDevDepMsgIn, tag: t, size: maxSize)
            _ = try transfer(bulkOut, NSMutableData(bytes: request, length: request.count))

            let n = try transfer(bulkIn, buffer)
            let header = try parseInHeader(UnsafeBufferPointer(start: bytes, count: n), tag: t)
            eom = header.eom
            var got = min(n - 12, header.size)
            out.append(bytes + 12, count: got)
            while got < header.size { // the rest of this message arrives without headers
                let m = try transfer(bulkIn, buffer)
                guard m > 0 else { throw ScopeError.protocolError("the scope stopped mid-reply") }
                out.append(bytes, count: min(m, header.size - got))
                got += m
            }
        }
        return out
    }

    public func query(_ command: String) throws -> String {
        try send(command)
        return String(decoding: try read(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The screen as a BMP (800x480, 24-bit), from `:DISP:DATA?`.
    public func screen() throws -> Data {
        try send(":DISP:DATA?")
        let reply = try read()
        guard let h = try parseBlockHeader(reply), reply.count >= h.headerLength + h.dataLength else {
            throw ScopeError.protocolError("the scope's screen reply was cut short")
        }
        let start = reply.startIndex + h.headerLength
        return reply.subdata(in: start ..< start + h.dataLength)
    }
}
