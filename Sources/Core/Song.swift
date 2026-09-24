import Foundation

public struct Step: Codable, Equatable {
    public var enabled = false
    public var note = 60
    public var velocity = 100
    public var gate = 0.65
    public init() {}
    public var noteName: String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        return "\(names[note % 12])\(note / 12 - 1)"
    }
}

public struct Pattern: Codable, Equatable {
    public var length = 16
    public var steps = Array(repeating: Step(), count: 64)
    public init() {}
}

public struct Song: Codable, Equatable {
    public var version = 1
    public var name = "Untitled session"
    public var bpm = 120.0
    public var channel = 1
    public var patterns = Array(repeating: Pattern(), count: 8)
    public var chain = [0]
    public init() {}

    public func validated() throws -> Song {
        guard version == 1, name.count <= 100, bpm.isFinite, (30...300).contains(bpm),
              (1...16).contains(channel), patterns.count == 8,
              (1...128).contains(chain.count), chain.allSatisfy({ (0..<8).contains($0) }),
              patterns.allSatisfy({ pattern in
                  [16, 32, 48, 64].contains(pattern.length) && pattern.steps.count == 64 &&
                  pattern.steps.allSatisfy { (0...127).contains($0.note) && (1...127).contains($0.velocity) &&
                      $0.gate.isFinite && (0.05...0.95).contains($0.gate) }
              }) else { throw SongError.invalid }
        return self
    }

    public static func decode(_ data: Data) throws -> Song {
        guard data.count <= 1_000_000 else { throw SongError.invalid }
        return try JSONDecoder().decode(Song.self, from: data).validated()
    }

    public func playback(loopPattern: Int?) -> [PlaybackStep] {
        let order = loopPattern.map { [$0] } ?? chain
        return order.enumerated().flatMap { position, bank in
            (0..<patterns[bank].length).map {
                PlaybackStep(bank: bank, step: $0, chainPosition: position, value: patterns[bank].steps[$0])
            }
        }
    }
}

public enum SongError: LocalizedError {
    case invalid
    public var errorDescription: String? { "This file is not a supported Pocket Sequence session." }
}

public struct PlaybackStep {
    public let bank: Int
    public let step: Int
    public let chainPosition: Int
    public let value: Step
}
