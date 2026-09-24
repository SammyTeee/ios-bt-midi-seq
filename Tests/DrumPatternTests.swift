import Foundation
import XCTest
@testable import SequenceCore

final class DrumPatternTests: XCTestCase {
    private var silentSteps: [[Bool]] {
        Array(repeating: Array(repeating: false, count: DrumPattern.stepCount), count: 4)
    }

    func testDefaultDimensionsAndPreset() {
        let pattern = DrumPattern()
        XCTAssertEqual(DrumPattern.stepCount, 16)
        XCTAssertEqual(pattern.bpm, 120)
        XCTAssertEqual(pattern.steps.count, 4)
        XCTAssertTrue(pattern.steps.allSatisfy { $0.count == 16 })
        XCTAssertEqual(pattern.steps[0].indices.filter { pattern.steps[0][$0] }, [0, 4, 8, 12])
        XCTAssertTrue(pattern.steps.allSatisfy { $0.contains(true) })
        XCTAssertEqual(DrumVoice.allCases.map { $0.rawValue }, [0, 1, 2, 3])
        XCTAssertEqual(DrumVoice.allCases.map { $0.name }, ["Kick", "Snare", "Hat", "Clap"])
    }

    func testDurationIsOneBar() {
        XCTAssertEqual(DrumPattern().samples().count, 88200)
        for bpm in [40.0, 123.0, 240.0] {
            for rate in [8000.0, 44100.0, 48000.0] {
                let pattern = DrumPattern(steps: silentSteps, bpm: bpm)
                XCTAssertEqual(pattern.samples(sampleRate: rate).count, Int((rate * (240 / bpm)).rounded(.down)))
            }
        }
    }

    func testDenseMixIsFiniteAndLimited() {
        let steps = Array(repeating: Array(repeating: true, count: 16), count: 4)
        let samples = DrumPattern(steps: steps, bpm: 240).samples(sampleRate: 8000)
        XCTAssertFalse(samples.isEmpty)
        XCTAssertTrue(samples.contains { $0 != 0 })
        XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
    }

    func testAllOffIsSilent() {
        let samples = DrumPattern(steps: silentSteps).samples(sampleRate: 8000)
        XCTAssertEqual(samples.count, 16000)
        XCTAssertTrue(samples.allSatisfy { $0 == 0 })
    }

    func testLastStepTailWrapsIntoBeginning() {
        var steps = silentSteps
        steps[DrumVoice.kick.rawValue][15] = true
        let rate = 8000.0
        let samples = DrumPattern(steps: steps, bpm: 240).samples(sampleRate: rate)
        let hit = DrumPattern.hit(.kick, sampleRate: rate)
        let onset = 7500
        var expected = [Float](repeating: 0, count: 8000)
        for index in hit.indices {
            expected[(onset + index) % expected.count] += hit[index]
        }
        XCTAssertEqual(samples, expected)
        XCTAssertTrue(samples.prefix(500).contains { $0 != 0 })
    }

    func testHitsAreDeterministicFiniteAndDistinct() {
        var hits: [[Float]] = []
        for voice in DrumVoice.allCases {
            let hit = DrumPattern.hit(voice)
            XCTAssertEqual(hit, DrumPattern.hit(voice))
            XCTAssertFalse(hit.isEmpty)
            XCTAssertTrue(hit.contains { $0 != 0 })
            XCTAssertTrue(hit.allSatisfy { $0.isFinite && abs($0) <= 1 })
            hits.append(hit)
        }
        for left in hits.indices {
            for right in hits.indices where left < right {
                XCTAssertNotEqual(hits[left], hits[right])
            }
        }
    }

    func testCodableRoundTripAndTempoBoundaries() throws {
        for bpm in [40.0, 120.0, 240.0] {
            var pattern = DrumPattern()
            pattern.bpm = bpm
            let data = try JSONEncoder().encode(pattern)
            XCTAssertEqual(try JSONDecoder().decode(DrumPattern.self, from: data), pattern)
        }
    }

    func testRejectsInvalidDimensionsAndTempo() throws {
        var shortRow = silentSteps
        shortRow[2].removeLast()
        var longRow = silentSteps
        longRow[1].append(false)
        let invalidSteps = [[], Array(silentSteps.prefix(3)), silentSteps + [silentSteps[0]], shortRow, longRow]
        for steps in invalidSteps {
            let data = try JSONEncoder().encode(DrumPattern(steps: steps))
            XCTAssertThrowsError(try JSONDecoder().decode(DrumPattern.self, from: data))
        }
        for bpm in [-1.0, 0.0, 39.9, 240.1] {
            let data = try JSONEncoder().encode(DrumPattern(steps: silentSteps, bpm: bpm))
            XCTAssertThrowsError(try JSONDecoder().decode(DrumPattern.self, from: data))
        }
        for json in ["{}", "{\"steps\":null,\"bpm\":120}", "{\"steps\":[],\"bpm\":\"fast\"}"] {
            XCTAssertThrowsError(try JSONDecoder().decode(DrumPattern.self, from: Data(json.utf8)))
        }
    }

    func testRejectsNonFiniteDecodedTempo() throws {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN"
        )
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN"
        )
        for bpm in [Double.infinity, -Double.infinity, Double.nan] {
            let data = try encoder.encode(DrumPattern(steps: silentSteps, bpm: bpm))
            XCTAssertThrowsError(try decoder.decode(DrumPattern.self, from: data))
        }
    }

    func testInvalidRuntimeStateAndSampleRatesAreSafe() {
        for rate in [0.0, -1.0, Double.nan, Double.infinity] {
            XCTAssertTrue(DrumPattern().samples(sampleRate: rate).isEmpty)
            for voice in DrumVoice.allCases {
                XCTAssertTrue(DrumPattern.hit(voice, sampleRate: rate).isEmpty)
            }
        }
        XCTAssertTrue(DrumPattern(steps: []).samples().isEmpty)
        for bpm in [0.0, 241.0, Double.nan, Double.infinity] {
            XCTAssertTrue(DrumPattern(steps: silentSteps, bpm: bpm).samples().isEmpty)
        }
    }
}
