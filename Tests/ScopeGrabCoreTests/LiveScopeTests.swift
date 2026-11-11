import Foundation
import Testing
@testable import ScopeGrabCore

/// Runs against the scope on USB when SCOPE_USB is set:
///   SCOPE_USB=1 swift test --filter Live
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SCOPE_USB"] != nil, "set SCOPE_USB=1 to run"), .serialized)
struct LiveScopeTests {
    @Test func screenIsAn800x480Bmp() throws {
        let t0 = Date()
        let bmp = try Scope.session { try $0.screen() }
        print("screen: \(bmp.count) bytes in \(String(format: "%.2f", Date().timeIntervalSince(t0))) s")
        #expect(bmp.prefix(2) == Data("BM".utf8))
        let w = bmp.subdata(in: 18..<22).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        let h = bmp.subdata(in: 22..<26).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        #expect(w == 800)
        #expect(abs(h) == 480)
    }

    @Test func twoQueriesOnOneSession() throws {
        let (idn, size) = try Scope.session { s in (try s.query("*IDN?"), try s.screen().count) }
        #expect(idn.contains("DS2"))
        #expect(size == 1_152_054)
    }

    @MainActor @Test func watcherSeesTheScope() async {
        var watcher: ScopeWatcher?
        let present = await withCheckedContinuation { cont in
            watcher = ScopeWatcher { cont.resume(returning: $0) }
        }
        #expect(present)
        _ = watcher
    }

    @Test func backToBackSessions() throws {
        for _ in 0..<3 { _ = try Scope.session { try $0.query("*IDN?") } }
    }
}
