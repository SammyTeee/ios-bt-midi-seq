import Foundation
import CoreMIDI
import CoreAudioKit
import SwiftUI
import Darwin

struct MIDIDestination: Identifiable, Equatable {
    let id: MIDIEndpointRef
    let name: String
}

final class MIDIConnection: ObservableObject {
    @Published var destinations: [MIDIDestination] = []
    @Published var selected: MIDIEndpointRef = 0
    @Published var error: String?
    private var client = MIDIClientRef()
    private(set) var port = MIDIPortRef()

    init() {
        let result = MIDIClientCreateWithBlock("Pocket Sequence" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        guard result == noErr else { error = "MIDI could not start (\(result))."; return }
        let outputResult = MIDIOutputPortCreate(client, "Sequence output" as CFString, &port)
        if outputResult != noErr { error = "MIDI output could not start (\(outputResult))." }
        refresh()
    }

    func refresh() {
        destinations = (0..<MIDIGetNumberOfDestinations()).map { index in
            let endpoint = MIDIGetDestination(index)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
            return MIDIDestination(id: endpoint, name: name?.takeRetainedValue() as String? ?? "MIDI device")
        }
        if !destinations.contains(where: { $0.id == selected }) { selected = 0 }
    }

    deinit {
        if port != 0 { MIDIPortDispose(port) }
        if client != 0 { MIDIClientDispose(client) }
    }
}

struct BluetoothPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CABTMIDICentralViewController {
        CABTMIDICentralViewController()
    }
    func updateUIViewController(_ controller: CABTMIDICentralViewController, context: Context) {}
}

/// All transport state and MIDI writes are serialized on this queue, independent of UI work.
final class SequencerEngine: ObservableObject {
    @Published private(set) var playing = false
    @Published private(set) var current: PlaybackStep?
    @Published var error: String?
    private let queue = DispatchQueue(label: "uk.co.lansystems.sequence.clock", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var destination = MIDIEndpointRef()
    private var port = MIDIPortRef()
    private var channel: UInt8 = 0
    private var events: [PlaybackStep] = []
    private var position = 0
    private var nextTime: UInt64 = 0
    private var interval: UInt64 = 0
    private var token = UUID()
    private var clockInfo = mach_timebase_info_data_t()

    init() { mach_timebase_info(&clockInfo) }

    private func ticks(_ seconds: Double) -> UInt64 {
        UInt64(seconds * 1_000_000_000 * Double(clockInfo.denom) / Double(clockInfo.numer))
    }

    func start(song: Song, bank: Int?, connection: MIDIConnection) {
        stop()
        guard connection.selected != 0, connection.port != 0 else {
            error = "Connect and select a MIDI output first."; return
        }
        guard (try? song.validated()) != nil else { error = "The session is invalid."; return }
        let run = UUID()
        token = run
        playing = true
        error = nil
        let output = connection.selected
        let outputPort = connection.port
        queue.sync {
            destination = output
            port = outputPort
            channel = UInt8(song.channel - 1)
            events = song.playback(loopPattern: bank)
            position = 0
            interval = ticks(60 / song.bpm / 4)
            nextTime = mach_absolute_time() + ticks(0.04)
            let clock = DispatchSource.makeTimerSource(queue: queue)
            clock.schedule(deadline: .now(), repeating: .milliseconds(4), leeway: .milliseconds(1))
            clock.setEventHandler { [weak self] in self?.pump(run: run) }
            timer = clock
            clock.resume()
        }
    }

    private func pump(run: UUID) {
        let now = mach_absolute_time()
        guard nextTime <= now + ticks(0.02) else { return }
        // Never burst missed notes after a stall: stop instead of racing to catch up.
        guard now <= nextTime + interval else {
            halt()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.token == run else { return }
                self.stop(); self.error = "Playback stopped after a timing interruption. Press Play to restart."
            }
            return
        }
        let event = events[position]
        if event.value.enabled {
            let note = UInt8(event.value.note)
            let on = send([0x90 | channel, note, UInt8(event.value.velocity)], at: nextTime)
            let off = send([0x80 | channel, note, 0], at: nextTime + UInt64(Double(interval) * event.value.gate))
            if on != noErr || off != noErr {
                halt()
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.token == run else { return }
                    self.stop(); self.error = "MIDI output failed. Reconnect your synth and select it again."
                }
                return
            }
        }
        let delayTicks = nextTime > now ? nextTime - now : 0
        let delay = Double(delayTicks) * Double(clockInfo.numer) / Double(clockInfo.denom) / 1_000_000_000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.token == run, self.playing else { return }
            self.current = event
        }
        position = (position + 1) % events.count
        nextTime += interval
    }

    @discardableResult private func send(_ bytes: [UInt8], at time: MIDITimeStamp = 0) -> OSStatus {
        var list = MIDIPacketList()
        return withUnsafeMutablePointer(to: &list) { pointer in
            let packet = MIDIPacketListInit(pointer)
            return bytes.withUnsafeBufferPointer { buffer in
                guard MIDIPacketListAdd(pointer, MemoryLayout<MIDIPacketList>.size, packet,
                                        time, bytes.count, buffer.baseAddress!) != nil else { return OSStatus(-1) }
                return MIDISend(port, destination, pointer)
            }
        }
    }

    private func halt() {
        timer?.cancel(); timer = nil
        guard destination != 0, port != 0 else { return }
        MIDIFlushOutput(destination)
        for note in UInt8(0)...UInt8(127) { send([0x80 | channel, note, 0]) }
        send([0xB0 | channel, 64, 0])
        send([0xB0 | channel, 123, 0])
        destination = 0
    }

    func stop() {
        token = UUID()
        queue.sync { halt() }
        playing = false
        current = nil
    }

    func panic(connection: MIDIConnection, midiChannel: Int) {
        stop()
        queue.sync {
            destination = connection.selected; port = connection.port
            channel = UInt8(midiChannel - 1)
            halt()
        }
    }
}
