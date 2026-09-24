import SwiftUI

struct ScalePanel: View {
    @Binding var scale: ScaleLock
    var quantize: () -> Void
    var body: some View {
        Form {
            Toggle("Lock notes to scale", isOn: $scale.enabled)
            Picker("Root", selection: $scale.root) { ForEach(0..<12, id: \.self) { Text(Palette.notes[$0]).tag($0) } }
            Picker("Scale", selection: $scale.scale) { ForEach(MusicalScale.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Text("New notes, piano-key entry, dragging and generation snap to this scale. Existing notes are preserved.").font(.footnote)
            Button("Snap existing notes in edited bank") { quantize() }.disabled(!scale.enabled)
        }
    }
}

struct GeneratorPanel: View {
    let length: Int
    let scale: ScaleLock
    var apply: (Pattern) -> Void
    @State private var seed = "42"
    @State private var density = 0.65
    @State private var octave = 4
    @State private var octaves = 1
    private var generated: Pattern {
        PatternEdit.generate(seed: UInt64(seed) ?? 0, length: length, density: density,
                             lowNote: octave * 12, octaves: octaves, scale: scale)
    }
    var body: some View {
        Form {
            Section("Repeatable seed") {
                TextField("Seed number", text: $seed).keyboardType(.numberPad).accessibilityIdentifier("generator-seed")
                Button("New seed", systemImage: "dice") { seed = String(UInt64.random(in: 0...999_999_999)) }
                if UInt64(seed) == nil { Text("Enter a whole number from 0 to 18446744073709551615.").foregroundStyle(.orange) }
            }
            Section("Shape") {
                Text("Notes: \(Int(density * 100))% · remaining steps are rests")
                Slider(value: $density, in: 0...1, step: 0.05)
                Picker("Lowest octave", selection: $octave) { ForEach(0...9, id: \.self) { Text(Palette.name($0 * 12)).tag($0) } }
                Picker("Range", selection: $octaves) { Text("1 octave").tag(1); Text("2 octaves").tag(2) }
                Text(scale.enabled ? "\(Palette.notes[scale.root]) \(scale.scale.rawValue) · scale locked" : "Chromatic · enable Scale lock to constrain notes").font(.footnote)
            }
            Section("Preview · \(length) steps") {
                Text(generated.steps.prefix(length).map { $0.enabled ? $0.noteName : "·" }.joined(separator: "  "))
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.lime)
                Button("Apply to edited bank") { apply(generated) }.disabled(UInt64(seed) == nil)
                    .accessibilityIdentifier("apply-generator")
                Text("Same seed + settings = same pattern. Apply replaces the current bank. Pattern tools → Undo restores it.").font(.footnote)
            }
        }.scrollDismissesKeyboard(.interactively)
    }
}
