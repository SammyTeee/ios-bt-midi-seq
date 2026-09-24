import XCTest
@testable import SequenceCore

final class PatternTransportTests: XCTestCase {
    func testQueuedPatternWaitsForWholePatternThenLoops() {
        var song = Song()
        song.patterns[0].length = 64
        var transport = PatternTransport(song: song, bank: 0)
        XCTAssertEqual(transport.next().bank, 0)
        transport.request(1)
        for index in 1..<64 {
            let event = transport.next()
            XCTAssertEqual(event.bank, 0)
            XCTAssertEqual(event.step, index)
        }
        XCTAssertEqual(transport.queuedBank, 1)
        let first = transport.next()
        XCTAssertEqual(first.bank, 1)
        XCTAssertEqual(first.step, 0)
        XCTAssertNil(transport.queuedBank)
        for _ in 0..<32 { XCTAssertEqual(transport.next().bank, 1) }
    }

    func testRequestDuringFinalStepIsNotDelayedAnExtraLoop() {
        var transport = PatternTransport(song: Song(), bank: 0)
        for _ in 0..<16 { _ = transport.next() }
        transport.request(7)
        XCTAssertEqual(transport.next().bank, 7)
    }

    func testReplaceAndCancelQueue() {
        var transport = PatternTransport(song: Song(), bank: 0)
        transport.request(1)
        transport.request(2)
        XCTAssertEqual(transport.queuedBank, 2)
        transport.request(2)
        XCTAssertNil(transport.queuedBank)
        transport.request(1)
        transport.request(0)
        XCTAssertNil(transport.queuedBank)
        transport.request(99)
        XCTAssertNil(transport.queuedBank)
    }

    func testChainAndLiveOverride() {
        var song = Song()
        song.chain = [0, 0, 2]
        var transport = PatternTransport(song: song, bank: nil)
        for _ in 0..<32 { XCTAssertEqual(transport.next().bank, 0) }
        XCTAssertEqual(transport.next().bank, 2)
        transport.request(5)
        for _ in 1..<16 { XCTAssertEqual(transport.next().bank, 2) }
        XCTAssertEqual(transport.next().bank, 5)
        XCTAssertFalse(transport.chaining)
        for _ in 0..<32 { XCTAssertEqual(transport.next().bank, 5) }
    }

    func testLiveEditsAreReadBeforeTheNextStep() {
        var transport = PatternTransport(song: Song(), bank: 0)
        _ = transport.next()
        transport.song.patterns[0].steps[1].enabled = true
        transport.song.patterns[0].steps[1].note = 72
        let event = transport.next()
        XCTAssertTrue(event.value.enabled)
        XCTAssertEqual(event.value.note, 72)
    }
}
