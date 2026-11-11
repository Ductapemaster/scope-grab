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
