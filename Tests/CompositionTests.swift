import XCTest
@testable import SequenceCore

final class CompositionTests: XCTestCase {
    func testStepRecordingWrapsAndRestAdvances() {
        var pattern = Pattern()
        var scale = ScaleLock(); scale.enabled = true
        XCTAssertEqual(PatternEdit.record(note: 61, at: 0, pattern: &pattern, scale: scale), 1)
        XCTAssertEqual(pattern.steps[0].note, 60)
        XCTAssertTrue(pattern.steps[0].enabled)
        XCTAssertEqual(PatternEdit.record(note: nil, at: 1, pattern: &pattern, scale: scale), 2)
        XCTAssertFalse(pattern.steps[1].enabled)
        XCTAssertEqual(PatternEdit.record(note: 67, at: 15, pattern: &pattern, scale: scale), 0)
    }

    func testGeneratorIsRepeatableAndScaleBound() throws {
        var scale = ScaleLock(); scale.enabled = true; scale.root = 2
        let a = PatternEdit.generate(seed: 42, length: 64, density: 0.6, lowNote: 48, octaves: 2, scale: scale)
        let b = PatternEdit.generate(seed: 42, length: 64, density: 0.6, lowNote: 48, octaves: 2, scale: scale)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.steps.allSatisfy { scale.contains($0.note) && (48...71).contains($0.note) })
        XCTAssertTrue(a.steps.contains { !$0.enabled })
        XCTAssertTrue(a.steps.contains { $0.enabled })
        XCTAssertNotEqual(a, PatternEdit.generate(seed: 43, length: 64, density: 0.6, lowNote: 48, octaves: 2, scale: scale))
        var song = Song(); song.patterns[0] = a
        XCTAssertNoThrow(try song.validated())
    }

    func testEmptyAndFullDensity() {
        let empty = PatternEdit.generate(seed: 0, length: 16, density: 0, lowNote: 60, octaves: 1, scale: ScaleLock())
        let full = PatternEdit.generate(seed: 0, length: 16, density: 1, lowNote: 60, octaves: 1, scale: ScaleLock())
        XCTAssertTrue(empty.steps.allSatisfy { !$0.enabled })
        XCTAssertTrue(full.steps.prefix(16).allSatisfy { $0.enabled })
    }

    func testScaleSnapAtMIDIBoundsAndLegacySession() throws {
        var scale = ScaleLock(); scale.enabled = true; scale.root = 11
        for note in -1...128 {
            XCTAssertTrue((0...127).contains(scale.snap(note)))
            XCTAssertTrue(scale.contains(scale.snap(note)))
        }
        let data = try JSONEncoder().encode(Song())
        XCTAssertNil(try Song.decode(data).scaleLock)
    }
}
