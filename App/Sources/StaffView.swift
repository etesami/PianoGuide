import PianoCore
import SwiftUI

/// Grand staff (treble + bass) that scrolls the song past a fixed cursor, like sheet music.
/// Played notes turn green, the next notes are blue (orange after a wrong note), and held wrong
/// keys show as red note heads at the cursor.
/// `scrollBeat` (the beat under the cursor) is animatable, so changing it slides the music smoothly.
struct StaffView: View, Animatable {
    var song: Song
    var noteStates: [Int: WaitModeEngine.NoteState] = [:]
    var wrongPitches: [UInt8] = []
    var scrollBeat: Double

    var animatableData: Double {
        get { scrollBeat }
        set { scrollBeat = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let m = Metrics(size: size)
            drawStaves(&context, m)
            drawClefsAndTime(&context, m)
            var music = context
            music.clip(to: Path(CGRect(x: m.musicStartX, y: 0, width: size.width - m.musicStartX, height: size.height)))
            drawBarlines(&music, m)
            drawNotes(&music, m)
            drawCursor(&context, m)
            for pitch in wrongPitches {
                let note = NoteEvent(id: -1, pitch: pitch, startBeat: 0, durationBeats: 1, velocity: 0)
                drawHead(&context, m, StaffLayout.place(note), x: m.cursorX + m.sp * 1.6, value: .quarter, color: .red)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
    }

    // MARK: Geometry

    private struct Metrics {
        let sp: CGFloat              // distance between two staff lines
        let trebleBottom: CGFloat    // y of the treble staff's bottom line
        let bassBottom: CGFloat
        let staffLeft: CGFloat
        let staffRight: CGFloat
        let musicStartX: CGFloat     // notes are clipped left of this (clefs live there)
        let cursorX: CGFloat
        let pxPerBeat: CGFloat

        init(size: CGSize) {
            // Height: 4 spaces of ledger room above, 4 for each staff, 6 between, 4 below.
            sp = size.height / 22
            trebleBottom = sp * 8
            bassBottom = sp * 18
            staffLeft = sp * 1.5
            staffRight = size.width - sp
            musicStartX = staffLeft + sp * 7
            cursorX = musicStartX + sp * 11      // room to see the last played notes
            pxPerBeat = sp * 8
        }

        func y(_ clef: Clef, position: Int) -> CGFloat {
            (clef == .treble ? trebleBottom : bassBottom) - CGFloat(position) * sp / 2
        }
    }

    /// x of a note's head center; the cursor sits just left of the note it is waiting for.
    private func x(atBeat beat: Double, _ m: Metrics) -> CGFloat {
        m.cursorX + m.sp * 1.6 + CGFloat(beat - scrollBeat) * m.pxPerBeat
    }

    // MARK: Drawing

    private func drawStaves(_ context: inout GraphicsContext, _ m: Metrics) {
        var lines = Path()
        for clef in [Clef.treble, .bass] {
            for position in stride(from: 0, through: 8, by: 2) {
                let y = m.y(clef, position: position)
                lines.move(to: CGPoint(x: m.staffLeft, y: y))
                lines.addLine(to: CGPoint(x: m.staffRight, y: y))
            }
        }
        // System line joining the two staves.
        lines.move(to: CGPoint(x: m.staffLeft, y: m.y(.treble, position: 8)))
        lines.addLine(to: CGPoint(x: m.staffLeft, y: m.bassBottom))
        context.stroke(lines, with: .color(.black), lineWidth: 1)
    }

    private func drawClefsAndTime(_ context: inout GraphicsContext, _ m: Metrics) {
        // Unicode musical symbols; the glyphs' baselines are tuned by eye.
        context.draw(Text("\u{1D11E}").font(.system(size: m.sp * 9.5)).foregroundColor(.black),
                     at: CGPoint(x: m.staffLeft + m.sp * 2, y: m.y(.treble, position: 3)))
        context.draw(Text("\u{1D122}").font(.system(size: m.sp * 5.5)).foregroundColor(.black),
                     at: CGPoint(x: m.staffLeft + m.sp * 2.2, y: m.y(.bass, position: 7)))
        let sig = song.initialTimeSignature
        for clef in [Clef.treble, .bass] {
            for (number, position) in [(sig.numerator, 6), (sig.denominator, 2)] {
                context.draw(Text("\(number)").font(.system(size: m.sp * 2.4, weight: .heavy, design: .serif))
                                .foregroundColor(.black),
                             at: CGPoint(x: m.staffLeft + m.sp * 5, y: m.y(clef, position: position)))
            }
        }
    }

    private func drawBarlines(_ context: inout GraphicsContext, _ m: Metrics) {
        var path = Path()
        for beat in song.barlineBeats {
            // Bar lines sit just before the first note of the bar.
            let x = x(atBeat: beat, m) - m.sp * 1.6
            path.move(to: CGPoint(x: x, y: m.y(.treble, position: 8)))
            path.addLine(to: CGPoint(x: x, y: m.bassBottom))
        }
        context.stroke(path, with: .color(.black.opacity(0.6)), lineWidth: 1)
    }

    private func drawNotes(_ context: inout GraphicsContext, _ m: Metrics) {
        let visibleBeats = Double((m.staffRight - m.musicStartX) / m.pxPerBeat)
        for note in song.notes {
            let x = x(atBeat: note.startBeat, m)
            guard x > m.musicStartX - m.sp * 3, note.startBeat < scrollBeat + visibleBeats + 1 else { continue }
            let color: Color
            switch noteStates[note.id] {
            case .played: color = .green
            case .next: color = .blue
            case .missed: color = .orange
            case nil: color = .black
            }
            drawHead(&context, m, StaffLayout.place(note), x: x,
                     value: NoteValue.from(beats: note.durationBeats), color: color)
        }
    }

    private func drawHead(_ context: inout GraphicsContext, _ m: Metrics, _ staff: StaffNote,
                          x: CGFloat, value: NoteValue, color: Color) {
        let y = m.y(staff.clef, position: staff.position)
        let headWidth = m.sp * 1.3

        var ledgers = Path()
        for position in staff.ledgerLines {
            let ly = m.y(staff.clef, position: position)
            ledgers.move(to: CGPoint(x: x - headWidth * 0.85, y: ly))
            ledgers.addLine(to: CGPoint(x: x + headWidth * 0.85, y: ly))
        }
        context.stroke(ledgers, with: .color(.black), lineWidth: 1)

        // Slightly tilted oval head.
        let rect = CGRect(x: -headWidth / 2, y: -m.sp / 2, width: headWidth, height: m.sp)
        let head = Path(ellipseIn: rect)
            .applying(CGAffineTransform(rotationAngle: -0.35).concatenating(CGAffineTransform(translationX: x, y: y)))
        if value.isHollow {
            context.stroke(head, with: .color(color), lineWidth: m.sp * 0.22)
        } else {
            context.fill(head, with: .color(color))
        }

        if staff.sharp {
            context.draw(Text("♯").font(.system(size: m.sp * 2)).foregroundColor(color),
                         at: CGPoint(x: x - headWidth * 1.15, y: y))
        }

        guard value.hasStem else { return }
        let stemX = staff.stemUp ? x + headWidth / 2 - 0.75 : x - headWidth / 2 + 0.75
        let stemEnd = staff.stemUp ? y - m.sp * 3.5 : y + m.sp * 3.5
        var stem = Path()
        stem.move(to: CGPoint(x: stemX, y: y))
        stem.addLine(to: CGPoint(x: stemX, y: stemEnd))
        for i in 0..<value.flags {
            let start = stemEnd + CGFloat(i) * (staff.stemUp ? m.sp : -m.sp) * 0.8
            stem.move(to: CGPoint(x: stemX, y: start))
            stem.addQuadCurve(to: CGPoint(x: stemX + m.sp * 0.9, y: start + (staff.stemUp ? m.sp * 2 : -m.sp * 2)),
                              control: CGPoint(x: stemX + m.sp * 0.2, y: start + (staff.stemUp ? m.sp : -m.sp)))
        }
        context.stroke(stem, with: .color(color), lineWidth: 1.5)
    }

    private func drawCursor(_ context: inout GraphicsContext, _ m: Metrics) {
        let top = m.y(.treble, position: 12)
        let bottom = m.y(.bass, position: -4)
        let glow = CGRect(x: m.cursorX - m.sp * 3, y: top, width: m.sp * 3, height: bottom - top)
        context.fill(Path(glow), with: .linearGradient(
            Gradient(colors: [.blue.opacity(0), .blue.opacity(0.35)]),
            startPoint: CGPoint(x: glow.minX, y: 0), endPoint: CGPoint(x: glow.maxX, y: 0)))
        context.fill(Path(CGRect(x: m.cursorX - 1.5, y: top, width: 3, height: bottom - top)), with: .color(.blue))
    }
}
