import Foundation

/// Builds `<YYYY-MM-DD HH-MM-SS> <label>.png`, or just the timestamp when the
/// label is blank. `/` and `:` in the label become `-`. When the name is taken,
/// appends ` 2`, ` 3` and so on.
public func captureFilename(label: String, date: Date, timeZone: TimeZone = .current,
                            exists: (String) -> Bool) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = timeZone
    f.dateFormat = "yyyy-MM-dd HH-mm-ss"
    let clean = label.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: ":", with: "-")
    let stem = clean.isEmpty ? f.string(from: date) : "\(f.string(from: date)) \(clean)"
    var name = "\(stem).png"
    var n = 2
    while exists(name) {
        name = "\(stem) \(n).png"
        n += 1
    }
    return name
}
