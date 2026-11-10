import Foundation
import Network

public enum ScopeError: Error, LocalizedError {
    case timedOut(String)
    case closed

    public var errorDescription: String? {
        switch self {
        case .timedOut(let what): return "timed out \(what)"
        case .closed: return "scope closed the connection"
        }
    }
}

/// A connection to the scope's raw SCPI socket (TCP 5555, `\n`-terminated).
public final class Scope: @unchecked Sendable {
    private let conn: NWConnection
    private let queue = DispatchQueue(label: "scope")
    private var buffer = Data()

    public init(host: String, port: UInt16 = 5555) {
        conn = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    }

    /// Opens a connection, runs `body`, and closes it. The whole exchange,
    /// connect included, must finish within `timeout`.
    public static func session<T: Sendable>(host: String, port: UInt16 = 5555,
                                            connectTimeout: TimeInterval = 3,
                                            timeout: TimeInterval = 10,
                                            _ body: @escaping @Sendable (Scope) async throws -> T) async throws -> T {
        let scope = Scope(host: host, port: port)
        defer { scope.conn.cancel() }
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await scope.connect(timeout: connectTimeout)
                return try await body(scope)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw ScopeError.timedOut("waiting for the scope")
            }
            defer { group.cancelAll(); scope.conn.cancel() }
            return try await group.next()!
        }
    }

    private func connect(timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let once = Once()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { cont.resume() }
                // .waiting means the connection can't be made right now (refused,
                // no route); fail fast instead of letting NWConnection retry.
                case .waiting(let e), .failed(let e): once.run { cont.resume(throwing: e) }
                case .cancelled: once.run { cont.resume(throwing: ScopeError.closed) }
                default: break
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) {
                once.run { cont.resume(throwing: ScopeError.timedOut("connecting to the scope")) }
            }
            conn.start(queue: queue)
        }
    }

    public func send(_ command: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: Data((command + "\n").utf8), completion: .contentProcessed { err in
                if let err { cont.resume(throwing: err) } else { cont.resume() }
            })
        }
    }

    /// Reads until `buffer` holds at least `count` bytes.
    private func fill(_ count: Int) async throws {
        while buffer.count < count {
            let chunk: Data = try await withCheckedThrowingContinuation { cont in
                conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { data, _, done, err in
                    if let err { cont.resume(throwing: err) }
                    else if let data, !data.isEmpty { cont.resume(returning: data) }
                    else if done { cont.resume(throwing: ScopeError.closed) }
                    else { cont.resume(returning: Data()) }
                }
            }
            buffer.append(chunk)
        }
    }

    private func take(_ count: Int) -> Data {
        let out = buffer.prefix(count)
        buffer.removeFirst(count)
        return Data(out)
    }

    /// Reads one `\n`-terminated reply line, without the terminator.
    public func readLine() async throws -> String {
        while true {
            if let i = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = take(i - buffer.startIndex + 1)
                return String(decoding: line.dropLast(), as: UTF8.self)
            }
            try await fill(buffer.count + 1)
        }
    }

    public func query(_ command: String) async throws -> String {
        try await send(command)
        return try await readLine()
    }

    /// Reads an IEEE 488.2 definite-length block and its trailing `\n`.
    public func readBlock() async throws -> Data {
        var header: (headerLength: Int, dataLength: Int)?
        while header == nil {
            header = try parseBlockHeader(buffer)
            if header == nil { try await fill(buffer.count + 1) }
        }
        let (h, n) = header!
        try await fill(h + n + 1)
        _ = take(h)
        let data = take(n)
        _ = take(1)
        return data
    }

    /// The scope's screen as an 800 × 480 24-bit BMP.
    public func screen() async throws -> Data {
        try await send(":DISP:DATA?")
        return try await readBlock()
    }
}

/// Runs a closure at most once, from any thread.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func run(_ f: () -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard !done else { return }
        done = true
        f()
    }
}
