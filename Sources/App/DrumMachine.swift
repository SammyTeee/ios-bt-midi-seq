import SwiftUI
import AVFoundation

final class DrumMachine: ObservableObject {
    @Published var pattern = DrumPattern() { didSet { save() } }
    @Published private(set) var playing = false
    @Published var error: String?
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var interruption: NSObjectProtocol?
    private let key = "drum-pattern-v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key) {
            do { pattern = try JSONDecoder().decode(DrumPattern.self, from: data) }
            catch { self.error = "Could not restore the drum pattern: \(error.localizedDescription)" }
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        interruption = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.stop() }
    }

    deinit {
        if let interruption { NotificationCenter.default.removeObserver(interruption) }
    }

    func play() { play(samples: pattern.samples(), loop: true) }
    func audition(_ voice: DrumVoice) { guard !playing else { return }; play(samples: DrumPattern.hit(voice), loop: false) }

    private func play(samples: [Float], loop: Bool) {
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
                  let channel = buffer.floatChannelData?[0] else {
                throw NSError(domain: "DrumMachine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not allocate drum audio."])
            }
            buffer.frameLength = buffer.frameCapacity
            for (index, sample) in samples.enumerated() { channel[index] = sample }
            try engine.start()
            // Render a whole bar so repetition is sample-accurate, independent of UI timers.
            player.scheduleBuffer(buffer, at: nil, options: loop ? [.loops] : [])
            player.play()
            playing = loop
            UIApplication.shared.isIdleTimerDisabled = loop
        } catch {
            stop()
            self.error = "Could not start drum audio: \(error.localizedDescription)"
        }
    }

    func stop() {
        player.stop()
        engine.stop()
        playing = false
        UIApplication.shared.isIdleTimerDisabled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func save() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(pattern), forKey: key) }
        catch { self.error = "Could not save the drum pattern: \(error.localizedDescription)" }
    }
}

struct DrumMachineView: View {
    @StateObject private var drums = DrumMachine()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var clearing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Button(drums.playing ? "Stop" : "Play", systemImage: drums.playing ? "stop.fill" : "play.fill") {
                            if drums.playing { drums.stop() } else { drums.play() }
                        }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                            .accessibilityIdentifier("drum-play")
                        Spacer()
                        Text("\(Int(drums.pattern.bpm)) BPM").monospacedDigit()
                    }
                    Slider(value: $drums.pattern.bpm, in: 40...240, step: 1)
                        .disabled(drums.playing).accessibilityLabel("Drum tempo")
                    Text("16 steps · one bar · synthesized sounds").font(.caption).foregroundStyle(.secondary)
                    GeometryReader { geometry in
                        let columns = geometry.size.width > 650 ? 16 : 8
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(DrumVoice.allCases, id: \.rawValue) { voice in
                                VStack(alignment: .leading, spacing: 6) {
                                    Button(voice.name, systemImage: "speaker.wave.2.fill") { drums.audition(voice) }
                                        .disabled(drums.playing).accessibilityLabel("Audition \(voice.name)")
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4) {
                                        ForEach(0..<DrumPattern.stepCount, id: \.self) { step in
                                            stepButton(voice, step: step)
                                        }
                                    }
                                }
                            }
                        }
                    }.frame(height: 440)
                    HStack {
                        Button("Starter beat") { drums.pattern = DrumPattern() }
                        Spacer()
                        Button("Clear", role: .destructive) { clearing = true }
                    }.disabled(drums.playing)
                    Text("Tap a sound name to audition. Stop to edit the beat or tempo. Audio plays through your phone or connected headphones; no MIDI device is needed. This beat is saved separately from your MIDI session.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
            .background(Palette.background)
            .navigationTitle("Drum machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { drums.stop(); dismiss() }.accessibilityIdentifier("drum-done")
                }
            }
            .confirmationDialog("Clear the drum pattern?", isPresented: $clearing) {
                Button("Clear pattern", role: .destructive) {
                    drums.pattern.steps = Array(repeating: Array(repeating: false, count: DrumPattern.stepCount), count: DrumVoice.allCases.count)
                }
            }
            .alert("Drum machine", isPresented: Binding(get: { drums.error != nil }, set: { if !$0 { drums.error = nil } })) {
                Button("OK", role: .cancel) { drums.error = nil }
            } message: { Text(drums.error ?? "") }
        }
        .tint(Palette.lime)
        .onDisappear { drums.stop() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { drums.stop() } }
    }

    private func stepButton(_ voice: DrumVoice, step: Int) -> some View {
        let enabled = drums.pattern.steps[voice.rawValue][step]
        return Button { drums.pattern.steps[voice.rawValue][step].toggle() } label: {
            Text("\(step + 1)").font(.caption.monospaced().bold())
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(enabled ? Palette.lime : Palette.panel, in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(enabled ? Color.black : Color.white)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(step % 4 == 0 ? Color.white.opacity(0.6) : .clear))
        }.buttonStyle(.plain).disabled(drums.playing)
            .accessibilityLabel("\(voice.name) step \(step + 1)")
            .accessibilityValue(enabled ? "On" : "Off")
            .accessibilityIdentifier("drum-\(voice.rawValue)-\(step)")
    }
}
