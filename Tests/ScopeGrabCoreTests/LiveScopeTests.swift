import Foundation
import Testing
@testable import ScopeGrabCore

/// Runs against a real scope or tools/fake_scope.py when SCOPE_HOST is set:
///   SCOPE_HOST=192.168.0.114 swift test --filter Live
private let host = ProcessInfo.processInfo.environment["SCOPE_HOST"]

/// Serialized: the scope stalls when two SCPI socket connections are open at
/// once, and both time out.
@Suite(.enabled(if: host != nil, "set SCOPE_HOST to run"), .serialized)
struct LiveScopeTests {
    @Test func screenIsAn800x480Bmp() async throws {
        let t0 = Date()
        let bmp = try await Scope.session(host: host!) { try await $0.screen() }
        print("screen: \(bmp.count) bytes in \(String(format: "%.2f", Date().timeIntervalSince(t0))) s")
        #expect(bmp.prefix(2) == Data("BM".utf8))
        let w = bmp.subdata(in: 18..<22).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        let h = bmp.subdata(in: 22..<26).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        #expect(w == 800)
        #expect(abs(h) == 480)
    }

    @Test func twoQueriesOnOneConnection() async throws {
        let (idn, size) = try await Scope.session(host: host!) { s in
            (try await s.query("*IDN?"), try await s.screen().count)
        }
        #expect(idn.contains("DS2"))
        #expect(size > 1_000_000)
    }

    /// Changes the scope's measurement bar (adds VPP and FREQ for each channel on).
    @Test func frozenCaptureReadsStableValuesAndRestoresRunState() async throws {
        let (before, result, again, after) = try await Scope.session(host: host!, timeout: 20) { s in
            let before = try await s.query(":TRIG:STAT?")
            let result = try await s.frozenCapture(items: ["VPP", "FREQuency"])
            try await Task.sleep(for: .milliseconds(500))
            let after = try await s.query(":TRIG:STAT?")
            // A second frozen capture must also read valid values.
            let again = try await s.frozenCapture(items: ["VPP", "FREQuency"])
            return (before, result, again, after)
        }
        print("frozen: \(result.values)  again: \(again.values)  state \(before) -> \(after)")
        #expect(result.screen.count == 1_152_054)
        #expect(result.values.contains { $0.channel == 1 && $0.item == "VPP" && $0.value != nil })
        #expect(again.values.allSatisfy { $0.value != nil } == result.values.allSatisfy { $0.value != nil })
        #expect((before == "STOP") == (after == "STOP"))
    }
}

@Test func refusedConnectionFailsFast() async throws {
    let t0 = Date()
    await #expect(throws: (any Error).self) {
        try await Scope.session(host: "127.0.0.1", port: 59999) { try await $0.screen() }
    }
    #expect(Date().timeIntervalSince(t0) < 3)
}

@Test func unreachableHostTimesOut() async throws {
    let t0 = Date()
    // 192.0.2.0/24 is reserved for documentation: nothing answers there.
    await #expect(throws: (any Error).self) {
        try await Scope.session(host: "192.0.2.1", connectTimeout: 1, timeout: 2) { try await $0.screen() }
    }
    #expect(Date().timeIntervalSince(t0) < 3)
}
