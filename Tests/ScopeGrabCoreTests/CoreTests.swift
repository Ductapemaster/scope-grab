import Foundation
import Testing
@testable import ScopeGrabCore

@Test func blockHeaderComplete() throws {
    let buf = Array("#9001152054BM".utf8)
    let h = try #require(try parseBlockHeader(buf))
    #expect(h.headerLength == 11)
    #expect(h.dataLength == 1_152_054)
}

@Test func blockHeaderNeedsMoreBytes() throws {
    #expect(try parseBlockHeader(Array<UInt8>()) == nil)
    #expect(try parseBlockHeader(Array("#".utf8)) == nil)
    #expect(try parseBlockHeader(Array("#900115".utf8)) == nil)
}

@Test func blockHeaderRejectsGarbage() {
    #expect(throws: BlockError.badStart(UInt8(ascii: "R"))) { try parseBlockHeader(Array("RIGOL".utf8)) }
    #expect(throws: BlockError.badHeader) { try parseBlockHeader(Array("#x12".utf8)) }
    #expect(throws: BlockError.badHeader) { try parseBlockHeader(Array("#0".utf8)) }
}

@Test func usbtmcOutHeader() {
    #expect(usbtmcHeader(.devDepMsgOut, tag: 1, size: 0x0102_0304, eom: true)
            == [1, 1, 0xFE, 0, 0x04, 0x03, 0x02, 0x01, 1, 0, 0, 0])
    #expect(usbtmcHeader(.requestDevDepMsgIn, tag: 7, size: 64)[0...3] == [2, 7, 0xF8, 0])
}

@Test func usbtmcInHeader() throws {
    let h = try parseInHeader([2, 5, 0xFA, 0, 0x0B, 0, 0, 0, 1, 0, 0, 0], tag: 5)
    #expect(h.size == 11)
    #expect(h.eom)
    #expect(throws: ScopeError.self) { try parseInHeader([2, 6, 0xF9, 0, 0, 0, 0, 0, 0, 0, 0, 0], tag: 5) }
    #expect(throws: ScopeError.self) { try parseInHeader([2, 5, 0xFA], tag: 5) }
}

private let utc = TimeZone(identifier: "UTC")!
private let date = Date(timeIntervalSince1970: 1_794_321_125) // 2026-11-10 14:32:05 UTC

@Test func filenameWithLabel() {
    #expect(captureFilename(label: "  TP4 IF out ", date: date, timeZone: utc) { _ in false }
            == "2026-11-10 14-32-05 TP4 IF out.png")
}

@Test func filenameBlankLabel() {
    #expect(captureFilename(label: " ", date: date, timeZone: utc) { _ in false } == "2026-11-10 14-32-05.png")
}

@Test func filenameSanitizesSlashAndColon() {
    #expect(captureFilename(label: "Q3 b/e 1:1", date: date, timeZone: utc) { _ in false }
            == "2026-11-10 14-32-05 Q3 b-e 1-1.png")
}

@Test func filenameAvoidsCollisions() {
    let taken: Set = ["2026-11-10 14-32-05 TP4.png", "2026-11-10 14-32-05 TP4 2.png"]
    #expect(captureFilename(label: "TP4", date: date, timeZone: utc) { taken.contains($0) }
            == "2026-11-10 14-32-05 TP4 3.png")
}

@Test func templateLabelFirst() {
    let t = FilenameTemplate("{label} {date} {time}")
    #expect(t.filename(label: "TP4", date: date, timeZone: utc) { _ in false } == "TP4 2026-11-10 14-32-05.png")
    // A blank label leaves no leading space.
    #expect(t.filename(label: "", date: date, timeZone: utc) { _ in false } == "2026-11-10 14-32-05.png")
}

@Test func templateTrimsDanglingSeparators() {
    let t = FilenameTemplate("{date}_{label}")
    #expect(t.filename(label: "", date: date, timeZone: utc) { _ in false } == "2026-11-10.png")
    #expect(t.filename(label: "TP4", date: date, timeZone: utc) { _ in false } == "2026-11-10_TP4.png")
}

@Test func templateWithoutLabelGetsItAppended() {
    #expect(FilenameTemplate("{time}").pattern == "{time} {label}")
    #expect(FilenameTemplate("  ").pattern == FilenameTemplate.standard)
}

@Test func templateLabelOnlyFallsBackToTimestampWhenBlank() {
    let t = FilenameTemplate("{label}")
    #expect(t.filename(label: "", date: date, timeZone: utc) { _ in false } == "2026-11-10 14-32-05.png")
}

@Test func templateParts() {
    let p = FilenameTemplate(FilenameTemplate.standard).parts(date: date, timeZone: utc)
    #expect(p.before == "2026-11-10 14-32-05 ")
    #expect(p.after == ".png")
}

@Test func pathTrailCollapsesHome() {
    #expect(pathTrail("/Users/dan/Lab Notes/Captures/", home: "/Users/dan") == ["~", "Lab Notes", "Captures"])
    #expect(pathTrail("/Users/dan", home: "/Users/dan") == ["~"])
    #expect(pathTrail("/Volumes/Shared/Bench", home: "/Users/dan") == ["/", "Volumes", "Shared", "Bench"])
    #expect(pathTrail("/Users/danny/x", home: "/Users/dan") == ["/", "Users", "danny", "x"])
}
