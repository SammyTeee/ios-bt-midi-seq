import XCTest
@testable import SequenceCore

final class SongTests: XCTestCase {
    func testChainKeepsRepeatsAndDifferentPatternLengths() {
        var song = Song()
        song.patterns[1].length = 64
        song.chain = [0, 0, 1, 2]
        let events = song.playback(loopPattern: nil)
        XCTAssertEqual(events.count, 112)
        XCTAssertEqual(events[16].bank, 0)
        XCTAssertEqual(events[16].chainPosition, 1)
        XCTAssertEqual(events[32].bank, 1)
        XCTAssertEqual(events[95].step, 63)
        XCTAssertEqual(events[96].bank, 2)
        XCTAssertEqual(song.playback(loopPattern: 1).count, 64)
    }

    func testRoundTripPreservesNotesAndRests() throws {
        var song = Song()
        song.patterns[3].steps[17].enabled = true
        song.patterns[3].steps[17].note = 127
        song.chain = [3, 0, 3]
        XCTAssertEqual(try Song.decode(JSONEncoder().encode(song)), song)
    }

    func testInvalidImportedDataIsRejected() throws {
        var song = Song()
        song.chain = [8]
        XCTAssertThrowsError(try song.validated())
        song = Song(); song.patterns[0].steps = []
        XCTAssertThrowsError(try song.validated())
        song = Song(); song.patterns[0].steps[0].note = -1
        XCTAssertThrowsError(try song.validated())
        song = Song(); song.bpm = 0
        XCTAssertThrowsError(try song.validated())
        song = Song(); song.chain = []
        XCTAssertThrowsError(try song.validated())
        song = Song(); song.patterns[0].steps[0].gate = 2
        XCTAssertThrowsError(try song.validated())
        XCTAssertThrowsError(try Song.decode(Data("{}".utf8)))
    }
}
