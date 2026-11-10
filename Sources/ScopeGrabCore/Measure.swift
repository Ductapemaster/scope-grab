import Foundation

public struct Measurement: Sendable, Equatable {
    public let item: String
    public let channel: Int
    /// nil when the scope reports the value as invalid (9.9e37).
    public let value: Double?
}

/// Parses a `:MEASure:<item>?` reply. The scope answers 9.9e37 for "no value".
public func parseMeasurement(_ reply: String) -> Double? {
    guard let v = Double(reply.trimmingCharacters(in: .whitespaces)), v.isFinite, abs(v) < 9e37 else { return nil }
    return v
}

extension Scope {
    /// Freezes the scope, captures the screen, reads measurements from the frozen
    /// waveform, then restores the run state, so the values match the picture.
    ///
    /// The items are enabled while the scope is still running: an item first
    /// enabled while stopped answers once, then 9.9e37 on every later read.
    /// Enabling also adds the item to the scope's measurement bar, so it shows
    /// in the screenshot. Channels that are switched off are skipped.
    public func frozenCapture(items: [String], channels: [Int] = [1, 2]) async throws
        -> (screen: Data, values: [Measurement])
    {
        let status = try await query(":TRIG:STAT?")
        let sweep = try await query(":TRIG:SWE?")
        let wasRunning = status != "STOP"

        var on: [Int] = []
        for ch in channels where try await query(":CHAN\(ch):DISP?") == "1" { on.append(ch) }

        do {
            if wasRunning {
                for ch in on { for item in items { _ = try await query(":MEAS:\(item)? CHAN\(ch)") } }
                try await send(":STOP")
                _ = try await query("*OPC?")
                let deadline = Date().addingTimeInterval(3)
                while try await query(":TRIG:STAT?") != "STOP" {
                    if Date() > deadline { throw ScopeError.timedOut("waiting for the scope to stop") }
                }
            }
            let screen = try await screen()
            var values: [Measurement] = []
            for ch in on {
                for item in items {
                    let reply = try await query(":MEAS:\(item)? CHAN\(ch)")
                    values.append(Measurement(item: item, channel: ch, value: parseMeasurement(reply)))
                }
            }
            if wasRunning { try await resume(sweep: sweep) }
            return (screen, values)
        } catch {
            if wasRunning { try? await resume(sweep: sweep) }
            throw error
        }
    }

    /// Re-arms single-shot mode if that was the sweep, otherwise runs.
    private func resume(sweep: String) async throws {
        try await send(sweep.hasPrefix("SING") ? ":SING" : ":RUN")
        _ = try await query("*OPC?")
    }
}
