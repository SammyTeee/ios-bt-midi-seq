import Foundation

/// Advances only when the clock requests the next step. A request made during
/// the final step is still honoured before the following pattern's first note.
public struct PatternTransport {
    public var song: Song
    public private(set) var bank: Int
    public private(set) var queuedBank: Int?
    public private(set) var chaining: Bool
    private var step = 0
    private var chainPosition = 0

    public init(song: Song, bank: Int?) {
        self.song = song
        self.bank = bank ?? song.chain[0]
        chaining = bank == nil
    }

    public mutating func request(_ target: Int) {
        guard song.patterns.indices.contains(target) else { return }
        if queuedBank == target || (target == bank && !chaining) {
            queuedBank = nil
        } else {
            queuedBank = target
        }
    }

    public mutating func next() -> PlaybackStep {
        if step >= song.patterns[bank].length {
            step = 0
            if let target = queuedBank {
                bank = target
                queuedBank = nil
                chaining = false
            } else if chaining {
                chainPosition = (chainPosition + 1) % song.chain.count
                bank = song.chain[chainPosition]
            }
        }
        let event = PlaybackStep(bank: bank, step: step, chainPosition: chainPosition,
                                 value: song.patterns[bank].steps[step])
        step += 1
        return event
    }
}
