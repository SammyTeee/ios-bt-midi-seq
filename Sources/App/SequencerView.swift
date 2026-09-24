import SwiftUI

struct SequencerView: View {
    @StateObject private var store = SessionStore()
    @StateObject private var midi = MIDIConnection()
    @StateObject private var engine = SequencerEngine()
    @Environment(\.scenePhase) private var scenePhase
    @State private var bank = 0
    @State private var page = 0
    @State private var selectedStep = 0
    @State private var songMode = false
    @State private var bluetooth = false
    @State private var importing = false
    @State private var exporting = false
    @State private var help = false
    @State private var clearPattern = false
    private let accent = Color(red: 0.74, green: 0.96, blue: 0.35)
    private let letters = Array("ABCDEFGH").map(String.init)

    private var step: Binding<Step> { $store.song.patterns[bank].steps[selectedStep] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    connection
                    transport
                    patternEditor
                    stepEditor
                    chainEditor
                    Text("Sessions save automatically. Keep the app open while playing.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
            .background(Color(red: 0.055, green: 0.067, blue: 0.065))
            .navigationTitle("Pocket Sequence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Export session", systemImage: "square.and.arrow.up") { exporting = true }
                        Button("Import session…", systemImage: "square.and.arrow.down") { importing = true }
                            .disabled(engine.playing)
                        Button("Connection guide", systemImage: "questionmark.circle") { help = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $bluetooth, onDismiss: { midi.refresh() }) {
                NavigationStack {
                    BluetoothPicker()
                        .navigationTitle("Bluetooth MIDI")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { bluetooth = false }
                        } }
                }
            }
            .sheet(isPresented: $help) { guide }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    engine.stop(); store.load(url); page = 0; selectedStep = 0
                case .failure(let error): store.error = error.localizedDescription
                }
            }
            .fileExporter(isPresented: $exporting, document: SessionDocument(song: store.song),
                          contentType: .json, defaultFilename: "Pocket-Sequence") { result in
                if case .failure(let error) = result { store.error = error.localizedDescription }
            }
            .alert("Pocket Sequence", isPresented: Binding(
                get: { store.error != nil || engine.error != nil || midi.error != nil },
                set: { if !$0 { store.error = nil; engine.error = nil; midi.error = nil } }
            )) { Button("OK", role: .cancel) {} } message: {
                Text(store.error ?? engine.error ?? midi.error ?? "")
            }
            .confirmationDialog("Clear all 64 steps in bank \(letters[bank])?", isPresented: $clearPattern) {
                Button("Clear pattern", role: .destructive) { store.song.patterns[bank] = Pattern(); page = 0; selectedStep = 0 }
            }
            .onChange(of: midi.selected) { _, _ in engine.stop() }
            .onChange(of: engine.playing) { _, playing in UIApplication.shared.isIdleTimerDisabled = playing }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { engine.stop() }
                if phase == .active { midi.refresh() }
            }
        }
        .tint(accent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MAKE ROOM FOR THE NEXT IDEA").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(accent)
            TextField("Session name", text: $store.song.name)
                .font(.largeTitle.weight(.bold)).disabled(engine.playing)
                .onChange(of: store.song.name) { _, name in
                    if name.count > 100 { store.song.name = String(name.prefix(100)) }
                }
            Text("Eight banks. Your synth. No sixteen-step ceiling.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(midi.selected == 0 ? "Choose your synth" : "MIDI output selected",
                      systemImage: midi.selected == 0 ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Connect") { bluetooth = true }.disabled(engine.playing)
            }
            Picker("Output", selection: $midi.selected) {
                Text("Select MIDI output").tag(UInt32(0))
                ForEach(midi.destinations) { Text($0.name).tag($0.id) }
            }.disabled(engine.playing)
            Stepper("MIDI channel \(store.song.channel)", value: $store.song.channel, in: 1...16)
                .font(.subheadline).disabled(engine.playing)
        }.padding(16).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private var transport: some View {
        VStack(spacing: 14) {
            HStack {
                Text("\(Int(store.song.bpm))").font(.system(size: 38, weight: .medium, design: .monospaced))
                Text("BPM").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { engine.panic(connection: midi, midiChannel: store.song.channel) } label: {
                    Image(systemName: "speaker.slash.fill").frame(width: 44, height: 44)
                }.accessibilityLabel("Panic: stop all notes")
                Button {
                    if engine.playing { engine.stop() }
                    else { engine.start(song: store.song, bank: songMode ? nil : bank, connection: midi) }
                } label: {
                    Label(engine.playing ? "Stop" : "Play", systemImage: engine.playing ? "stop.fill" : "play.fill")
                        .font(.headline).frame(minWidth: 84).padding(.vertical, 10)
                }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                    .disabled(!engine.playing && midi.selected == 0)
            }
            Slider(value: $store.song.bpm, in: 30...300, step: 1).disabled(engine.playing)
                .accessibilityLabel("Tempo")
            Picker("Playback", selection: $songMode) {
                Text("Loop bank").tag(false)
                Text("Play chain").tag(true)
            }.pickerStyle(.segmented).disabled(engine.playing)
            if let current = engine.current {
                Text("PLAYING \(letters[current.bank]) · STEP \(current.step + 1)\(songMode ? " · CHAIN \(current.chainPosition + 1)" : "")")
                    .font(.caption.monospaced()).foregroundStyle(accent)
            }
        }
    }

    private var patternEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PATTERNS").font(.caption.weight(.bold)).tracking(2)
                Spacer()
                Menu {
                    ForEach(0..<8, id: \.self) { target in
                        if target != bank {
                            Button("Copy \(letters[bank]) to \(letters[target])") {
                                store.song.patterns[target] = store.song.patterns[bank]
                            }
                        }
                    }
                    Button("Clear bank…", role: .destructive) { clearPattern = true }
                } label: { Image(systemName: "doc.on.doc") }.disabled(engine.playing)
            }
            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { index in
                    Button(letters[index]) { bank = index; page = 0; selectedStep = 0 }
                        .font(.headline.monospaced()).frame(maxWidth: .infinity, minHeight: 44)
                        .background(bank == index ? accent : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(bank == index ? .black : .white)
                        .accessibilityLabel("Pattern \(letters[index])")
                }
            }
            HStack {
                Text("Bank \(letters[bank])").font(.headline)
                Spacer()
                Picker("Pattern length", selection: $store.song.patterns[bank].length) {
                    ForEach([16, 32, 48, 64], id: \.self) { Text("\($0) steps").tag($0) }
                }.disabled(engine.playing)
                    .onChange(of: store.song.patterns[bank].length) { _, length in
                        page = min(page, length / 16 - 1); selectedStep = page * 16
                    }
            }
            HStack {
                ForEach(0..<(store.song.patterns[bank].length / 16), id: \.self) { index in
                    Button("\(index * 16 + 1)–\(index * 16 + 16)") { page = index; selectedStep = index * 16 }
                        .buttonStyle(.bordered).tint(page == index ? accent : .gray)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(page * 16..<(page * 16 + 16), id: \.self) { index in
                    stepCell(index)
                }
            }
            Text(engine.playing ? "Stop playback to edit notes, tempo or the chain." : "Tap a step to select it. Tap it again to switch it on or off.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func stepCell(_ index: Int) -> some View {
        let value = store.song.patterns[bank].steps[index]
        let active = engine.current?.bank == bank && engine.current?.step == index
        return Button {
            if selectedStep == index { store.song.patterns[bank].steps[index].enabled.toggle() }
            selectedStep = index
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(format: "%02d", index + 1)).font(.caption2.monospaced())
                    Spacer()
                    Circle().fill(value.enabled ? accent : .gray.opacity(0.3)).frame(width: 6, height: 6)
                }
                Text(value.enabled ? value.noteName : "—").font(.title3.monospaced().weight(.semibold))
            }.padding(12).frame(maxWidth: .infinity, minHeight: 70)
                .background(active ? accent.opacity(0.28) : .white.opacity(value.enabled ? 0.10 : 0.035), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedStep == index ? accent : .clear, lineWidth: 2))
        }.buttonStyle(.plain).disabled(engine.playing)
            .accessibilityLabel("Step \(index + 1), \(value.enabled ? value.noteName : "rest")")
    }

    private var stepEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Step \(selectedStep + 1) · \(step.wrappedValue.noteName)", isOn: step.enabled)
                .font(.headline)
            Stepper("Note: \(step.wrappedValue.noteName) (\(step.wrappedValue.note))", value: step.note, in: 0...127)
            HStack {
                Button("− Octave") { step.wrappedValue.note = max(0, step.wrappedValue.note - 12) }
                Spacer()
                Button("+ Octave") { step.wrappedValue.note = min(127, step.wrappedValue.note + 12) }
            }.buttonStyle(.bordered)
            Stepper("Velocity: \(step.wrappedValue.velocity)", value: step.velocity, in: 1...127)
            HStack {
                Text("Gate \(Int(step.wrappedValue.gate * 100))%")
                Slider(value: step.gate, in: 0.05...0.95, step: 0.05).accessibilityLabel("Note gate")
            }
        }.padding(16).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            .disabled(engine.playing)
    }

    private var chainEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SONG CHAIN").font(.caption.weight(.bold)).tracking(2)
            Text("Add banks in playback order. The chain loops when it reaches the end.")
                .font(.subheadline).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Array(store.song.chain.enumerated()), id: \.offset) { position, item in
                        Button {
                            if store.song.chain.count > 1 { store.song.chain.remove(at: position) }
                        } label: {
                            VStack(spacing: 6) {
                                Text("\(position + 1)").font(.caption2)
                                Text(letters[item]).font(.title2.monospaced().bold())
                            }.frame(width: 48, height: 66)
                                .background(songMode && engine.current?.chainPosition == position ? accent.opacity(0.3) : .white.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).disabled(engine.playing)
                            .accessibilityLabel("Chain position \(position + 1), pattern \(letters[item]). Tap to remove.")
                    }
                }
            }
            Menu("Add pattern to chain", systemImage: "plus.circle") {
                ForEach(0..<8, id: \.self) { index in
                    Button("Bank \(letters[index])") { store.song.chain.append(index) }
                }
            }.disabled(engine.playing || store.song.chain.count >= 128)
            Text("Tap a chain entry to remove it. At least one entry stays.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var guide: some View {
        NavigationStack {
            List {
                Section("Connect your FM-1") {
                    Text("1. Enable Bluetooth on the FM-1 (long-press HOME/BT).")
                    Text("2. Tap Connect here and select the FM-1 in the Bluetooth MIDI list. This is separate from ordinary Bluetooth audio pairing.")
                    Text("3. Close the list, select the FM-1 as Output, and match the MIDI channel to the synth's receive channel.")
                    Text("4. Stop the FM-1's internal sequencer and arpeggiator. Enable some steps here, then press Play.")
                }
                Section("Playback") {
                    Text("Each step is a sixteenth note. Loop bank repeats the selected bank; Play chain repeats your full arrangement. Choose the bank before pressing Play.")
                    Text("This version sends one note per step. Notes and rests are sequenced on the phone; it does not change the synth's stored patterns.")
                    Text("Listen through the FM-1 speaker or its audio output. Bluetooth MIDI does not stream audio to the phone.")
                    Text("Playback stops when the app goes into the background or the output disconnects. The screen stays awake while playing. Use the crossed-out speaker button to stop stuck notes.")
                    Text("USB MIDI also works if iOS exposes your connected synth as a MIDI output.")
                }
                Section("Save your music") {
                    Text("Your current session saves automatically. Use Export session to keep multiple songs in Files, then Import session to load one. Import replaces the current session; export it first if you want to keep it.")
                }
            }.navigationTitle("Quick start")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { help = false } } }
        }
    }
}
