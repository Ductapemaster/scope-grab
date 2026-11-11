import Foundation
import IOKit

/// Reports whether the scope is on USB, live. macOS notifies on attach and detach,
/// so this neither polls nor sends the scope anything.
public final class ScopeWatcher {
    private let port: IONotificationPortRef
    private var iterators: [io_iterator_t] = []
    private var count = 0
    private let onChange: (Bool) -> Void

    /// `onChange` runs on the main queue: once at start, then on every attach or detach.
    public init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, .main)

        let context = Unmanaged.passUnretained(self).toOpaque()
        for (type, delta) in [(kIOFirstMatchNotification, 1), (kIOTerminatedNotification, -1)] {
            let match = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
            match["IOPropertyMatch"] = ["idVendor": Scope.vendorID, "idProduct": Scope.productID]
            var iterator: io_iterator_t = 0
            let callback: IOServiceMatchingCallback = delta > 0
                ? { ctx, it in Unmanaged<ScopeWatcher>.fromOpaque(ctx!).takeUnretainedValue().drain(it, 1) }
                : { ctx, it in Unmanaged<ScopeWatcher>.fromOpaque(ctx!).takeUnretainedValue().drain(it, -1) }
            IOServiceAddMatchingNotification(port, type, match as CFDictionary, callback, context, &iterator)
            iterators.append(iterator)
            drain(iterator, delta, notify: false) // arms the notification and counts what's already there
        }
        let present = count > 0
        DispatchQueue.main.async { onChange(present) }
    }

    deinit {
        iterators.forEach { IOObjectRelease($0) }
        IONotificationPortDestroy(port)
    }

    private func drain(_ iterator: io_iterator_t, _ delta: Int, notify: Bool = true) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            count = max(0, count + delta)
            IOObjectRelease(service)
        }
        if notify { onChange(count > 0) }
    }
}
