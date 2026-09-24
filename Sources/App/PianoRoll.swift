import SwiftUI

enum Palette {
    static let background = Color(red: 0.045, green: 0.055, blue: 0.06)
    static let panel = Color(red: 0.085, green: 0.10, blue: 0.11)
    static let lime = Color(red: 0.75, green: 0.96, blue: 0.38)
    static let amber = Color(red: 1, green: 0.72, blue: 0.3)
    static let notes = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    static let banks = Array("ABCDEFGH").map(String.init)
    static func name(_ note: Int) -> String { "\(notes[note % 12])\(note / 12 - 1)" }
}

struct PianoRoll: View {
    @Binding var pattern: Pattern
    @Binding var selected: Int
    var page: Int
    var columns: Int
    var octave: Int
    var scale: ScaleLock
    var playingStep: Int?
    var recording: Bool
    var onKey: (Int) -> Void
    var onEdit: (Pattern) -> Void
    @State private var original: Pattern?
    @State private var sourceIndex = 0
    @State private var sourceNote = 60
    @State private var movingExisting = false
    @State private var moved = false
    private let keyWidth: CGFloat = 43
    private let header: CGFloat = 20
    private var lowNote: Int { octave * 12 }

    var body: some View {
        GeometryReader { geometry in
            let gridWidth = max(1, geometry.size.width - keyWidth)
            let gridHeight = max(1, geometry.size.height - header)
            let rowHeight = gridHeight / 12
            let columnWidth = gridWidth / CGFloat(columns)
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    draw(context: &context, size: size, rowHeight: rowHeight, columnWidth: columnWidth)
                }.allowsHitTesting(false)
                // Keys are real controls for reliable step entry and accessibility.
                VStack(spacing: 0) {
                    ForEach((0..<12).reversed(), id: \.self) { offset in
                        let note = lowNote + offset
                        Button { if note <= 127 { onKey(note) } } label: {
                            Text(note <= 127 ? Palette.name(note) : "")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .frame(width: keyWidth - 2, height: rowHeight)
                                .background(keyColor(note))
                                .foregroundStyle(isBlack(note) ? Color.white : Color.black)
                                .opacity(scale.enabled && !scale.contains(note) ? 0.35 : 1)
                        }.buttonStyle(.plain).disabled(note > 127)
                            .accessibilityIdentifier("piano-key-\(note)")
                            .accessibilityLabel("\(Palette.name(note)), \(recording ? "enter note" : "set selected note")")
                    }
                }.offset(y: header)
                Color.clear.contentShape(Rectangle())
                    .frame(width: gridWidth, height: gridHeight)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let start = cell(value.startLocation, columnWidth: columnWidth, rowHeight: rowHeight)
                            let target = cell(value.location, columnWidth: columnWidth, rowHeight: rowHeight)
                            if original == nil {
                                original = pattern; sourceIndex = start.0; sourceNote = start.1
                                movingExisting = pattern.steps[start.0].enabled && pattern.steps[start.0].note == start.1
                                selected = start.0; moved = false
                            }
                            if !recording && abs(value.translation.width) + abs(value.translation.height) > 5 {
                                moved = true
                                var copy = original ?? pattern
                                var note = movingExisting ? copy.steps[sourceIndex] : Step()
                                if movingExisting { copy.steps[sourceIndex].enabled = false }
                                note.note = target.1; note.enabled = true
                                copy.steps[target.0] = note
                                pattern = copy; selected = target.0
                            }
                        }
                        .onEnded { value in
                            guard let before = original else { return }
                            if !moved {
                                let target = cell(value.location, columnWidth: columnWidth, rowHeight: rowHeight)
                                if recording {
                                    // In step-record mode grid taps move the entry cursor only.
                                    selected = target.0
                                } else {
                                    pattern.steps[target.0].enabled = !(before.steps[target.0].enabled && before.steps[target.0].note == target.1)
                                    pattern.steps[target.0].note = target.1
                                    selected = target.0
                                }
                            }
                            if pattern != before { onEdit(before) }
                            original = nil; moved = false
                        })
                    .offset(x: keyWidth, y: header)
                    .accessibilityIdentifier("piano-roll-grid")
                    .accessibilityLabel("Piano roll. Tap to add or remove a note; drag to move it.")
            }
        }
        .background(Palette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func cell(_ point: CGPoint, columnWidth: CGFloat, rowHeight: CGFloat) -> (Int, Int) {
        let column = min(columns - 1, max(0, Int(point.x / columnWidth)))
        let row = min(11, max(0, Int(point.y / rowHeight)))
        return (min(pattern.length - 1, page * columns + column), scale.snap(lowNote + 11 - row))
    }

    private func isBlack(_ note: Int) -> Bool { [1, 3, 6, 8, 10].contains(note % 12) }
    private func keyColor(_ note: Int) -> Color { isBlack(note) ? Color(white: 0.14) : Color(white: 0.83) }

    private func draw(context: inout GraphicsContext, size: CGSize, rowHeight: CGFloat, columnWidth: CGFloat) {
        let start = page * columns
        for row in 0..<12 {
            let note = lowNote + 11 - row
            let rect = CGRect(x: keyWidth, y: header + CGFloat(row) * rowHeight,
                              width: size.width - keyWidth, height: rowHeight)
            let alpha = scale.enabled && !scale.contains(note) ? 0.005 : (isBlack(note) ? 0.025 : 0.065)
            context.fill(Path(rect), with: .color(.white.opacity(alpha)))
            var line = Path(); line.move(to: CGPoint(x: keyWidth, y: rect.maxY)); line.addLine(to: CGPoint(x: size.width, y: rect.maxY))
            context.stroke(line, with: .color(.black.opacity(0.4)), lineWidth: 0.5)
        }
        for column in 0..<columns {
            let index = start + column
            guard index < pattern.length else { continue }
            let x = keyWidth + CGFloat(column) * columnWidth
            if playingStep == index {
                context.fill(Path(CGRect(x: x, y: header, width: columnWidth, height: size.height - header)), with: .color(Palette.lime.opacity(0.13)))
            }
            if selected == index {
                context.fill(Path(CGRect(x: x, y: 0, width: columnWidth, height: header)), with: .color(recording ? Palette.amber.opacity(0.5) : .white.opacity(0.2)))
            }
            context.draw(Text("\(index + 1)").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray),
                         at: CGPoint(x: x + columnWidth / 2, y: header / 2))
            var line = Path(); line.move(to: CGPoint(x: x, y: header)); line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(.white.opacity(index % 4 == 0 ? 0.23 : 0.06)), lineWidth: 1)
            let step = pattern.steps[index]
            guard step.enabled else { continue }
            let row = 11 - (step.note - lowNote)
            if !(0..<12).contains(row) {
                context.draw(Text(row < 0 ? "↑" : "↓").font(.caption).foregroundColor(Palette.lime),
                             at: CGPoint(x: x + columnWidth / 2, y: row < 0 ? header + 7 : size.height - 7))
                continue
            }
            let rect = CGRect(x: x + 2, y: header + CGFloat(row) * rowHeight + 1,
                              width: max(7, (columnWidth - 4) * step.gate), height: max(3, rowHeight - 2))
            let path = Path(roundedRect: rect, cornerRadius: 3)
            context.fill(path, with: .color(Palette.lime.opacity(0.5 + Double(step.velocity) / 254)))
            if selected == index { context.stroke(path, with: .color(.white), lineWidth: 1.5) }
        }
    }
}
