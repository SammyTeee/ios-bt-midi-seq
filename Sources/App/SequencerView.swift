import SwiftUI

struct SequencerView: View {
    @StateObject private var store = SessionStore()
    @StateObject private var midi = MIDIConnection()
    @StateObject private var engine = SequencerEngine()
    @StateObject private var drums = DrumMachine()
    @Environment(\.scenePhase) private var scenePhase
    @State private var bank = 0
    @State private var page = 0
    @State private var selected = 0
    @State private var octave = 5
    @State private var stepRecord = false
    @State private var songMode = false
    @State private var follow = true
    @State private var panel: Panel?
    @State private var bluetooth = false
    @State private var showingDrums = false
    @State private var importing = false
    @State private var exporting = false
    @State private var clearing = false
    @State private var undo: (bank: Int, pattern: Pattern)?
    private enum Panel: String, Identifiable { case midi, tempo, scale, generator, session, chain, help; var id: String { rawValue } }
    private var scale: ScaleLock { store.song.scaleLock ?? ScaleLock() }
    private var scaleBinding: Binding<ScaleLock> { Binding(get: { scale }, set: { store.song.scaleLock = $0 }) }
    private var step: Binding<Step> { $store.song.patterns[bank].steps[selected] }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height
            let columns = wide || geometry.size.width > 650 ? 16 : 8
            VStack(spacing: wide ? 6 : 12) {
                toolbar(wide: wide)
                launcher(wide: wide)
                editorBar(columns: columns)
                PianoRoll(pattern: $store.song.patterns[bank], selected: $selected, page: page,
                          columns: columns, octave: octave, scale: scale,
                          playingStep: engine.current?.bank == bank ? engine.current?.step : nil,
                          recording: stepRecord, onKey: { enterKey($0, columns: columns) },
                          onEdit: { undo = (bank, $0) }).frame(maxHeight: .infinity)
                entryBar(columns: columns, wide: wide)
                if stepRecord {
                    NoteKeyboard(octave: octave, scale: scale, onKey: { enterKey($0, columns: columns) })
                        .frame(height: wide ? 54 : 78)
                } else if !wide { noteInspector }
            }
            .padding(.horizontal, wide ? 12 : 14).padding(.vertical, wide ? 4 : 8)
            .background(Palette.background)
            .onChange(of: columns) { _, count in page = selected / count }
            .onChange(of: selected) { _, index in page = index / columns }
            .onChange(of: engine.current?.bank) { _, newBank in
                if follow, let newBank, !stepRecord { selectBank(newBank) }
            }
        }
        .tint(Palette.lime)
        .sheet(item: $panel) { panelView($0) }
        .fullScreenCover(isPresented: $showingDrums) { DrumMachineView(drums: drums) }
        .sheet(isPresented: $bluetooth, onDismiss: { midi.refresh() }) {
            NavigationStack {
                BluetoothPicker().navigationTitle("Bluetooth MIDI").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { bluetooth = false } } }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): engine.stop(); store.load(url); selectBank(0); undo = nil
            case .failure(let error): store.error = error.localizedDescription
            }
        }
        .fileExporter(isPresented: $exporting, document: SessionDocument(song: store.song), contentType: .json,
                      defaultFilename: "Pocket-Sequence") { result in
            if case .failure(let error) = result { store.error = error.localizedDescription }
        }
        .alert("Pocket Sequence", isPresented: Binding(
            get: { store.error != nil || engine.error != nil || midi.error != nil },
            set: { if !$0 { store.error = nil; engine.error = nil; midi.error = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(store.error ?? engine.error ?? midi.error ?? "") }
        .confirmationDialog("Clear bank \(Palette.banks[bank])?", isPresented: $clearing) {
            Button("Clear pattern", role: .destructive) {
                remember(); store.song.patterns[bank] = Pattern(); selected = 0; page = 0
            }
        }
        .onChange(of: store.song) { _, song in engine.update(song: song) }
        .onChange(of: panel) { _, value in if value != nil { follow = false } }
        .onChange(of: midi.selected) { _, _ in engine.stop() }
        .onChange(of: engine.playing || drums.playing) { _, playing in
            UIApplication.shared.isIdleTimerDisabled = playing
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { drums.stop() }
            if phase == .background { engine.stop() }
            if phase == .active { midi.refresh() }
        }
    }

    private func toolbar(wide: Bool) -> some View {
        HStack(spacing: 12) {
            if !wide { Text("POCKET / SEQ").font(.caption.weight(.black)).tracking(1) }
            Button { panel = .midi } label: {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(midi.selected == 0 ? .gray : Palette.lime).frame(width: 32, height: 36)
            }.accessibilityLabel("MIDI setup")
            Button { panel = .tempo } label: {
                Text("\(Int(store.song.bpm)) BPM").font(.system(.subheadline, design: .monospaced).weight(.semibold))
            }
            Spacer(minLength: 0)
            if wide { status.font(.caption.monospaced()).lineLimit(1) }
            Button { engine.panic(connection: midi, midiChannel: store.song.channel) } label: {
                Image(systemName: "speaker.slash").frame(width: 28, height: 36)
            }.accessibilityLabel("Panic")
            Button {
                if engine.playing { engine.stop() }
                else { engine.start(song: store.song, bank: songMode ? nil : bank, connection: midi) }
            } label: {
                Image(systemName: engine.playing ? "stop.fill" : "play.fill").frame(width: 32, height: 28)
            }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                .disabled(!engine.playing && midi.selected == 0).accessibilityLabel(engine.playing ? "Stop" : "Play")
            Menu {
                Button("Seed generator", systemImage: "dice") { panel = .generator }
                Button("Scale lock", systemImage: "lock") { panel = .scale }
                Button("Song chain", systemImage: "link") { panel = .chain }
                Button("Session & files", systemImage: "folder") { panel = .session }
                Button("Quick guide", systemImage: "questionmark.circle") { panel = .help }
            } label: { Image(systemName: "ellipsis.circle").frame(width: 28, height: 36) }.accessibilityLabel("Tools")
        }.frame(height: 40)
    }

    private var status: some View {
        Group {
            if let queued = engine.queuedBank {
                Text("\(Palette.banks[engine.current?.bank ?? bank]) → \(Palette.banks[queued]) NEXT").foregroundStyle(Palette.amber)
            } else if let current = engine.current {
                Text("\(Palette.banks[current.bank]) · \(current.step + 1)/\(store.song.patterns[current.bank].length)").foregroundStyle(Palette.lime)
            } else { Text(midi.selected == 0 ? "CONNECT MIDI" : "READY").foregroundStyle(.secondary) }
        }
    }

    private func launcher(wide: Bool) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { index in
                    let active = engine.playing && engine.current?.bank == index
                    let queued = engine.queuedBank == index
                    Button {
                        if engine.playing { engine.queuePattern(index); songMode = false }
                        else {
                            selectBank(index)
                            if midi.selected != 0 { songMode = false; engine.start(song: store.song, bank: index, connection: midi) }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            HStack(spacing: 4) {
                                Text(Palette.banks[index]).font(.system(.headline, design: .monospaced))
                                if active || queued { Image(systemName: queued ? "clock.fill" : "play.fill").font(.system(size: 8)) }
                            }
                            if !wide { Text(queued ? "NEXT" : active ? "PLAY" : "\(store.song.patterns[index].length)").font(.system(size: 8, weight: .bold)) }
                        }.frame(maxWidth: .infinity, minHeight: wide ? 38 : 51)
                            .background(queued ? Palette.amber : active ? Palette.lime : Palette.panel, in: RoundedRectangle(cornerRadius: 7))
                            .foregroundStyle(active || queued ? .black : .white)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(bank == index ? .white.opacity(0.8) : .clear, lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityIdentifier("launch-\(Palette.banks[index])")
                        .accessibilityLabel("Pattern \(Palette.banks[index])\(queued ? ", queued" : active ? ", playing" : "")")
                        .contextMenu { Button("Edit bank \(Palette.banks[index])") { follow = false; selectBank(index) } }
                }
            }
            HStack {
                if !wide { status.font(.caption.monospaced()) }
                Spacer()
                if drums.playing {
                    Button("Stop drums", systemImage: "stop.fill") { drums.stop() }
                        .font(.caption.weight(.semibold)).accessibilityIdentifier("stop-drums")
                }
                Button("Drums", systemImage: "square.grid.3x3.fill") {
                    showingDrums = true
                }.font(.caption.weight(.semibold)).accessibilityIdentifier("open-drums")
                    .accessibilityValue(drums.playing ? "Playing" : "Stopped")
            }
        }
    }

    private func editorBar(columns: Int) -> some View {
        HStack(spacing: 8) {
            Menu("Edit \(Palette.banks[bank])") {
                ForEach(0..<8, id: \.self) { index in Button("Bank \(Palette.banks[index])") { follow = false; selectBank(index) } }
                Toggle("Follow playing pattern", isOn: $follow)
            }.font(.subheadline.weight(.semibold))
            Menu("\(store.song.patterns[bank].length) steps") {
                ForEach([16, 32, 48, 64], id: \.self) { length in
                    Button("\(length) steps") {
                        remember(); store.song.patterns[bank].length = length
                        selected = min(selected, length - 1); page = selected / columns
                    }.disabled(engine.playing)
                }
            }.font(.caption)
            Spacer(minLength: 1)
            Button { panel = .scale } label: { Image(systemName: scale.enabled ? "lock.fill" : "lock.open") }.accessibilityLabel("Scale lock")
            Menu(Palette.name(octave * 12)) {
                ForEach(0...10, id: \.self) { index in Button("Octave \(index - 1) · \(Palette.name(index * 12))") { octave = index } }
                Button("Show selected note") { octave = step.wrappedValue.note / 12 }
            }.font(.caption.monospaced()).accessibilityLabel("Visible octave")
            Menu {
                Button("Undo last edit", systemImage: "arrow.uturn.backward") { undoEdit() }.disabled(undo == nil || engine.playing)
                Button("Generate…", systemImage: "dice") { panel = .generator }
                ForEach(0..<8, id: \.self) { index in
                    if index != bank { Button("Copy to \(Palette.banks[index])") {
                        undo = (index, store.song.patterns[index]); store.song.patterns[index] = store.song.patterns[bank]
                    }.disabled(engine.playing) }
                }
                Button("Clear…", role: .destructive) { clearing = true }.disabled(engine.playing)
            } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("Pattern tools")
        }.frame(height: 30)
    }

    private func entryBar(columns: Int, wide: Bool) -> some View {
        HStack(spacing: 8) {
            Button { stepRecord.toggle(); if stepRecord { follow = false } } label: {
                Label(wide ? "REC" : "Step Record", systemImage: stepRecord ? "record.circle.fill" : "record.circle").font(.caption.weight(.bold))
            }.buttonStyle(.bordered).tint(stepRecord ? Palette.amber : .gray)
                .accessibilityIdentifier("step-record").accessibilityValue(stepRecord ? "On" : "Off")
            if stepRecord {
                Button("Rest →") { recordEntry(nil) }
                    .font(.caption.weight(.semibold)).accessibilityIdentifier("record-rest")
            } else {
                Button { remember(); step.wrappedValue.enabled = false } label: { Image(systemName: "eraser") }.accessibilityLabel("Erase selected step")
            }
            Text("\(selected + 1) · \(step.wrappedValue.enabled ? step.wrappedValue.noteName : "Rest")")
                .font(.caption.monospaced()).foregroundStyle(stepRecord ? Palette.amber : Color.gray)
                .accessibilityIdentifier("entry-cursor")
            Spacer(minLength: 0)
            if wide {
                Menu("Note") {
                    Button("Soft") { step.wrappedValue.velocity = 65 }
                    Button("Normal") { step.wrappedValue.velocity = 100 }
                    Button("Accent") { step.wrappedValue.velocity = 127 }
                    ForEach([0.25, 0.5, 0.75, 0.95], id: \.self) { gate in Button("Gate \(Int(gate * 100))%") { step.wrappedValue.gate = gate } }
                }.font(.caption)
            }
            Menu("\(page * columns + 1)–\(min((page + 1) * columns, store.song.patterns[bank].length))") {
                ForEach(0..<(store.song.patterns[bank].length / columns), id: \.self) { number in
                    Button("Steps \(number * columns + 1)–\((number + 1) * columns)") { page = number; selected = number * columns }
                }
            }.font(.caption.monospaced()).accessibilityLabel("Step page")
        }.frame(height: 36)
    }

    private var noteInspector: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Velocity \(step.wrappedValue.velocity)").font(.caption2).foregroundStyle(.secondary)
                Slider(value: Binding(get: { Double(step.wrappedValue.velocity) }, set: { step.wrappedValue.velocity = Int($0) }), in: 1...127, step: 1).accessibilityLabel("Velocity")
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Gate \(Int(step.wrappedValue.gate * 100))%").font(.caption2).foregroundStyle(.secondary)
                Slider(value: step.gate, in: 0.05...0.95, step: 0.05).accessibilityLabel("Gate")
            }
        }.frame(height: 42)
    }

    private func selectBank(_ index: Int) {
        bank = index; selected = 0; page = 0
        if let first = store.song.patterns[index].steps.prefix(store.song.patterns[index].length).first(where: { $0.enabled }) { octave = first.note / 12 }
    }
    private func remember() { undo = (bank, store.song.patterns[bank]) }
    private func undoEdit() {
        guard let undo else { return }; store.song.patterns[undo.bank] = undo.pattern; selectBank(undo.bank); self.undo = nil
    }
    private func enterKey(_ rawNote: Int, columns: Int) {
        let note = scale.snap(rawNote)
        if stepRecord {
            recordEntry(note); page = selected / columns
        } else { remember(); step.wrappedValue.note = note; step.wrappedValue.enabled = true }
        engine.audition(note: note, velocity: 100, connection: midi, midiChannel: store.song.channel)
    }
    private func recordEntry(_ note: Int?) {
        remember()
        var pattern = store.song.patterns[bank]
        let next = PatternEdit.record(note: note, at: selected, pattern: &pattern, scale: scale)
        store.song.patterns[bank] = pattern
        selected = next
    }

    @ViewBuilder private func panelView(_ value: Panel) -> some View {
        NavigationStack {
            Group {
                switch value {
                case .midi: midiPanel
                case .tempo: Form {
                    Text("\(Int(store.song.bpm)) BPM").font(.largeTitle.monospaced())
                    Slider(value: $store.song.bpm, in: 30...300, step: 1).disabled(engine.playing)
                    Text("Sixteenth-note steps. Stop playback to change tempo.").font(.footnote)
                }
                case .scale: ScalePanel(scale: scaleBinding, quantize: {
                    remember()
                    for index in 0..<64 { store.song.patterns[bank].steps[index].note = scale.snap(store.song.patterns[bank].steps[index].note) }
                })
                case .generator: GeneratorPanel(length: store.song.patterns[bank].length, scale: scale, apply: { pattern in
                    remember(); store.song.patterns[bank] = pattern; selectBank(bank); panel = nil
                })
                case .session: sessionPanel
                case .chain: chainPanel
                case .help: helpPanel
                }
            }.navigationTitle(value.rawValue.capitalized).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { panel = nil } } }
        }.tint(Palette.lime).preferredColorScheme(.dark)
    }

    private var midiPanel: some View {
        Form {
            Section("Output") {
                Button("Connect Bluetooth MIDI…") { panel = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { bluetooth = true } }.disabled(engine.playing)
                Picker("Device", selection: $midi.selected) {
                    Text("Select output").tag(UInt32(0)); ForEach(midi.destinations) { Text($0.name).tag($0.id) }
                }.disabled(engine.playing)
                Picker("MIDI channel", selection: $store.song.channel) { ForEach(1...16, id: \.self) { Text("\($0)").tag($0) } }.disabled(engine.playing)
            }
            Section {
                Text("Enable FM-1 Bluetooth with HOME/BT. Connect here, select its output, and match the note channel. Stop the synth's own sequencer and arp.")
                Text("Listen through the FM-1. Keep this app open during playback; backgrounding stops it. Piano keys audition while stopped, and edit without extra notes during playback.")
            }.font(.subheadline)
        }
    }
    private var sessionPanel: some View {
        Form {
            TextField("Session name", text: $store.song.name).onChange(of: store.song.name) { _, value in if value.count > 100 { store.song.name = String(value.prefix(100)) } }
            Button("Export session…") { panel = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { exporting = true } }
            Button("Import session…") { panel = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { importing = true } }.disabled(engine.playing)
            Text("Sessions save automatically. Export to keep multiple songs. Import replaces the current session; export first to keep it.").font(.footnote)
        }
    }
    private var chainPanel: some View {
        Form {
            Toggle("Play saved chain", isOn: $songMode).disabled(engine.playing)
            Text("Play starts the saved chain. Tapping a launcher takes over at the next pattern boundary.").font(.footnote)
            ForEach(Array(store.song.chain.enumerated()), id: \.offset) { offset, item in
                HStack { Text("\(offset + 1). Bank \(Palette.banks[item])"); Spacer()
                    Button(role: .destructive) { store.song.chain.remove(at: offset) } label: { Image(systemName: "minus.circle") }
                        .disabled(engine.playing || store.song.chain.count == 1)
                }
            }
            Menu("Append bank") { ForEach(0..<8, id: \.self) { index in Button(Palette.banks[index]) { store.song.chain.append(index) } } }
                .disabled(engine.playing || store.song.chain.count >= 128)
        }
    }
    private var helpPanel: some View {
        List {
            Section("Perform") {
                Text("Tap a pattern to launch it. While playing, the next pattern waits until the current one finishes. Green is playing; amber is queued. Another tap replaces the queue; tapping the queued bank cancels it.")
                Text("Use Edit A/B… to inspect a bank without launching it. Follow playing pattern switches the editor at the boundary. The white outline shows the bank being edited.")
            }
            Section("Write") {
                Text("Tap an empty piano-roll cell to add a note; tap that note to erase it. Drag to move. One note per step; gaps are rests.")
                Text("Enable Step Record, then tap the piano keys to enter notes in order. Rest advances without a note. Tap the grid to place the cursor. It wraps at the pattern end.")
                Text("The octave and step-page menus reach other notes and steps. Arrows mark notes outside the visible octave. Rotate for a wider 16-step view; portrait shows eight steps. Disable iPhone Rotation Lock if needed.")
            }
            Section("Create variations") {
                Text("Scale lock snaps new/moved notes. Existing notes change only with Snap existing notes. The generator repeats a pattern from the same seed and settings. Apply replaces the bank; Undo restores it.")
                Text("Glide is not included. Gate sets note duration within a step. Playback is foreground-only and controls the synth externally.")
            }
        }.font(.subheadline)
    }
}
