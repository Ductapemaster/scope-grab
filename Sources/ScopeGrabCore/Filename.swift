import Foundation

/// A capture filename pattern. `{date}` becomes `YYYY-MM-DD`, `{time}` becomes
/// `HH-MM-SS` (both local time), and `{label}` becomes the label typed for the capture.
/// A template without `{label}` gets it appended, so a typed label is never dropped.
public struct FilenameTemplate: Equatable {
    public static let standard = "{date} {time} {label}"

    public let pattern: String

    public init(_ pattern: String) {
        let p = pattern.trimmingCharacters(in: .whitespaces)
        if p.isEmpty { self.pattern = Self.standard }
        else if p.contains("{label}") { self.pattern = p }
        else { self.pattern = p + " {label}" }
    }

    /// The rendered text before and after the label, for showing the name around the label field.
    public func parts(date: Date, timeZone: TimeZone = .current) -> (before: String, after: String) {
        let r = pattern.range(of: "{label}")!
        return (expand(String(pattern[..<r.lowerBound]), date, timeZone),
                expand(String(pattern[r.upperBound...]), date, timeZone) + ".png")
    }

    /// The filename for a capture. Separators left dangling by a blank label are trimmed,
    /// `/` and `:` become `-`, and a taken name gets ` 2`, ` 3` and so on.
    public func filename(label: String, date: Date, timeZone: TimeZone = .current,
                         exists: (String) -> Bool) -> String {
        let clean = label.trimmingCharacters(in: .whitespacesAndNewlines)
        var stem = expand(pattern, date, timeZone).replacingOccurrences(of: "{label}", with: clean)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        stem = stem.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " -_."))
        if stem.isEmpty { stem = expand("{date} {time}", date, timeZone) }
        var name = "\(stem).png"
        var n = 2
        while exists(name) {
            name = "\(stem) \(n).png"
            n += 1
        }
        return name
    }

    private func expand(_ s: String, _ date: Date, _ timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        let d = f.string(from: date)
        f.dateFormat = "HH-mm-ss"
        let t = f.string(from: date)
        return s.replacingOccurrences(of: "{date}", with: d).replacingOccurrences(of: "{time}", with: t)
    }
}

/// `<YYYY-MM-DD HH-MM-SS> <label>.png`: the standard template.
public func captureFilename(label: String, date: Date, timeZone: TimeZone = .current,
                            exists: (String) -> Bool) -> String {
    FilenameTemplate(FilenameTemplate.standard).filename(label: label, date: date, timeZone: timeZone, exists: exists)
}
