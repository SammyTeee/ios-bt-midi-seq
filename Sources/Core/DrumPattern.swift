import Foundation

enum DrumVoice: Int, CaseIterable {
    case kick, snare, hat, clap

    var name: String {
        switch self {
        case .kick: return "Kick"
        case .snare: return "Snare"
        case .hat: return "Hat"
        case .clap: return "Clap"
        }
    }
}

struct DrumPattern: Codable, Equatable {
    static let stepCount = 16

    var steps: [[Bool]] = [
        [0, 4, 8, 12],
        [4, 12],
        [0, 2, 4, 6, 8, 10, 12, 14],
        [12]
    ].map { beats in (0..<16).map { beats.contains($0) } }
    var bpm: Double = 120

    init() {}

    init(steps: [[Bool]], bpm: Double = 120) {
        self.steps = steps
        self.bpm = bpm
    }

    private enum CodingKeys: String, CodingKey {
        case steps, bpm
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        steps = try container.decode([[Bool]].self, forKey: .steps)
        bpm = try container.decode(Double.self, forKey: .bpm)
        guard Self.validSteps(steps) else {
            throw DecodingError.dataCorruptedError(
                forKey: .steps, in: container,
                debugDescription: "Expected four drum rows of 16 steps each."
            )
        }
        guard bpm.isFinite, (40...240).contains(bpm) else {
            throw DecodingError.dataCorruptedError(
                forKey: .bpm, in: container,
                debugDescription: "Tempo must be finite and between 40 and 240 BPM."
            )
        }
    }

    private static func validSteps(_ steps: [[Bool]]) -> Bool {
        steps.count == DrumVoice.allCases.count && steps.allSatisfy { $0.count == stepCount }
    }

    // Invalid runtime edits or sample rates produce no audio rather than trapping.
    func samples(sampleRate: Double = 44100) -> [Float] {
        guard Self.validSteps(steps), bpm.isFinite, (40...240).contains(bpm),
              sampleRate.isFinite, sampleRate > 0 else { return [] }
        let length = (sampleRate * (240 / bpm)).rounded(.down)
        guard length >= 1, length < Double(Int.max) else { return [] }
        let count = Int(length)
        var mix = [Float](repeating: 0, count: count)
        for voice in DrumVoice.allCases {
            let sound = Self.hit(voice, sampleRate: sampleRate)
            for step in 0..<Self.stepCount where steps[voice.rawValue][step] {
                var index = Int((Double(step) * sampleRate * (15 / bpm)).rounded(.down)) % count
                for sample in sound {
                    mix[index] += sample
                    index += 1
                    if index == count { index = 0 }
                }
            }
        }
        return mix.map { min(1, max(-1, $0)) }
    }

    static func hit(_ voice: DrumVoice, sampleRate: Double = 44100) -> [Float] {
        guard sampleRate.isFinite, sampleRate > 0 else { return [] }
        let duration: Double
        switch voice {
        case .kick: duration = 0.5
        case .snare: duration = 0.25
        case .hat: duration = 0.1
        case .clap: duration = 0.3
        }
        let length = (duration * sampleRate).rounded(.up)
        guard length >= 1, length < Double(Int.max) else { return [] }
        var result = [Float](repeating: 0, count: Int(length))
        var seed: UInt32 = 0x12345678 &+ UInt32(voice.rawValue)
        var previousNoise = 0.0
        for index in result.indices {
            let time = Double(index) / sampleRate
            seed = 1664525 &* seed &+ 1013904223
            let noise = Double(seed) / Double(UInt32.max) * 2 - 1
            let highNoise = (noise - previousNoise) * 0.5
            previousNoise = noise
            let value: Double
            switch voice {
            case .kick:
                // Integral of a decaying pitch sweep, ending near 48 Hz.
                let phase = 2 * Double.pi * (48 * time + 110 * 0.025 * (1 - exp(-time / 0.025)))
                value = sin(phase) * exp(-time * 10) * 0.85
            case .snare:
                value = (noise * 0.65 + sin(2 * Double.pi * 180 * time) * 0.25) * exp(-time * 22)
            case .hat:
                value = highNoise * exp(-time * 55) * 0.55
            case .clap:
                let bursts = [0.0, 0.012, 0.024].reduce(0.0) { envelope, onset in
                    envelope + (time >= onset ? exp(-(time - onset) * 65) : 0)
                }
                value = highNoise * (bursts * 0.35 + exp(-time * 18) * 0.2)
            }
            let fade = min(1, max(0, (duration - time) / 0.005))
            result[index] = Float(min(1, max(-1, value * fade)))
        }
        return result
    }
}
