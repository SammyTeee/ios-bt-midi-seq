import Foundation

public enum MusicalScale: String, Codable, CaseIterable {
    case minor = "Minor", major = "Major", dorian = "Dorian"
    case minorPentatonic = "Minor pentatonic", majorPentatonic = "Major pentatonic"
    case chromatic = "Chromatic"
    public var intervals: [Int] {
        switch self {
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .minorPentatonic: return [0, 3, 5, 7, 10]
        case .majorPentatonic: return [0, 2, 4, 7, 9]
        case .chromatic: return Array(0..<12)
        }
    }
}

public struct ScaleLock: Codable, Equatable {
    public var enabled = false
    public var root = 0
    public var scale = MusicalScale.minor
    public init() {}
    public func contains(_ note: Int) -> Bool {
        scale.intervals.contains(((note - root) % 12 + 12) % 12)
    }
    public func snap(_ note: Int) -> Int {
        let bounded = min(127, max(0, note))
        guard enabled else { return bounded }
        return (0...127).filter { contains($0) }.min {
            let a = abs($0 - bounded), b = abs($1 - bounded)
            return a == b ? $0 < $1 : a < b
        } ?? bounded
    }
}

public enum PatternEdit {
    public static func record(note: Int?, at cursor: Int, pattern: inout Pattern, scale: ScaleLock) -> Int {
        let index = min(pattern.length - 1, max(0, cursor))
        if let note {
            pattern.steps[index].note = scale.snap(note)
            pattern.steps[index].enabled = true
        } else { pattern.steps[index].enabled = false }
        return (index + 1) % pattern.length
    }

    public static func generate(seed: UInt64, length: Int, density: Double, lowNote: Int,
                                octaves: Int, scale: ScaleLock) -> Pattern {
        var random = SeedRandom(seed: seed)
        var pattern = Pattern()
        pattern.length = [16, 32, 48, 64].contains(length) ? length : 16
        let lower = min(127, max(0, lowNote))
        let upper = min(127, lower + max(1, octaves) * 12 - 1)
        let notes = (lower...upper).filter { !scale.enabled || scale.contains($0) }
        guard !notes.isEmpty else { return pattern }
        for index in 0..<pattern.length {
            pattern.steps[index].enabled = random.unit() < min(1, max(0, density))
            pattern.steps[index].note = notes[Int(random.next() % UInt64(notes.count))]
            pattern.steps[index].velocity = 75 + Int(random.next() % 46)
            pattern.steps[index].gate = [0.35, 0.5, 0.65, 0.8][Int(random.next() % 4)]
        }
        return pattern
    }
}

private struct SeedRandom {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed &+= 0x9E3779B97F4A7C15
        var value = seed
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
}
