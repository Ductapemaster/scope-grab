import Foundation

/// A folder path as the names a person reads, outermost first: the home folder becomes
/// `~`, and a path outside it starts at `/`. `/Users/dan/Bench/Captures` → `["~", "Bench", "Captures"]`.
public func pathTrail(_ path: String, home: String = NSHomeDirectory()) -> [String] {
    let clean = (path as NSString).standardizingPath
    let homeClean = (home as NSString).standardizingPath
    if clean == homeClean { return ["~"] }
    if clean.hasPrefix(homeClean + "/") {
        return ["~"] + clean.dropFirst(homeClean.count + 1).split(separator: "/").map(String.init)
    }
    return ["/"] + clean.split(separator: "/").map(String.init)
}
