import Foundation

public enum BlockError: Error, LocalizedError, Equatable {
    case badStart(UInt8)
    case badHeader

    public var errorDescription: String? {
        switch self {
        case .badStart(let b): return "unexpected reply from scope (first byte 0x\(String(b, radix: 16)))"
        case .badHeader: return "malformed block header from scope"
        }
    }
}

/// Parses the header of an IEEE 488.2 definite-length block: `#`, one digit N,
/// then N digits giving the byte count of the data that follows.
///
/// Returns nil when `buf` doesn't hold the whole header yet.
public func parseBlockHeader(_ buf: some Collection<UInt8>) throws -> (headerLength: Int, dataLength: Int)? {
    let bytes = Array(buf.prefix(11))
    guard let first = bytes.first else { return nil }
    guard first == UInt8(ascii: "#") else { throw BlockError.badStart(first) }
    guard bytes.count >= 2 else { return nil }
    guard let n = Int(String(UnicodeScalar(bytes[1]))), n > 0 else { throw BlockError.badHeader }
    guard bytes.count >= 2 + n else { return nil }
    guard let length = Int(String(decoding: bytes[2..<2 + n], as: UTF8.self)) else { throw BlockError.badHeader }
    return (2 + n, length)
}
