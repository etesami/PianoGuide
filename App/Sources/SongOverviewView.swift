import PianoCore
import SwiftUI

/// The whole song in small staves that scroll vertically, four bars to a line, grouped into its sections: the same letter
/// and color mean the same music. It says where each section comes back, and marks the bars a near-repeat changes.
/// The hand picker looks for repeats in one hand only, with the other staff greyed out.
struct SongOverviewView: View {
    let song: Song
    let showFingers: Bool
    /// Worked out once: the screen around this view redraws often.
    @State private var form: SongForm?
    /// The hand whose repeats are shown (nil = both). Back to both when the overview closes.
    @State private var clef: Clef?

    private static let barsPerLine = 4
    private static let lineHeight: CGFloat = 170
    private static let tints: [Color] = [
        Color(red: 0.84, green: 0.91, blue: 1.00),
        Color(red: 0.85, green: 0.95, blue: 0.84),
        Color(red: 0.95, green: 0.88, blue: 0.98),
        Color(red: 1.00, green: 0.95, blue: 0.78),
        Color(red: 0.83, green: 0.95, blue: 0.95),
        Color(red: 0.99, green: 0.87, blue: 0.87),
    ]

    var body: some View {
        ScrollView {
            if let form {
                LazyVStack(alignment: .leading, spacing: 16) {
                    handPicker
                    summary(form)
                    tips
                    ForEach(form.sections, id: \.bars.lowerBound) { section(form, $0) }
                }
            }
        }
        .onAppear { form = SongForm(song: song, clef: clef) }
        .onChange(of: clef) { _, new in form = SongForm(song: song, clef: new) }
    }

    private var handPicker: some View {
        Picker("Hand", selection: $clef) {
            Text("Both Hands").tag(Clef?.none)
            Text("Left Hand").tag(Clef?.some(.bass))
            Text("Right Hand").tag(Clef?.some(.treble))
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 420)
    }

    private var handName: String {
        switch clef {
        case .bass: return "the left hand"
        case .treble: return "the right hand"
        case nil: return "this song"
        }
    }

    private func tint(_ form: SongForm, _ section: SongForm.Section) -> Color {
        guard form.hasRepeats else { return .white }
        return section.isRests ? Color(white: 0.93) : Self.tints[section.letterIndex % Self.tints.count]
    }

    private func summary(_ form: SongForm) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if form.hasRepeats {
                HStack(spacing: 6) {
                    ForEach(Array(form.sections.enumerated()), id: \.offset) { _, section in
                        letter(section, tint: tint(form, section))
                    }
                }
                Text("\(form.barCount) bars, \(form.barsToLearn) to learn").font(.headline)
            } else if form.barsToLearn == 0 {
                Text("Nothing to play in \(handName)").font(.headline)
            } else {
                Text("No repeated sections found in \(handName)").font(.headline)
                Text("Its \(form.barsToLearn) played bars are all new, apart from single bars that come back on their own.")
                    .font(.subheadline).foregroundColor(.secondary)
            }
        }
    }

    private func letter(_ section: SongForm.Section, tint: Color) -> some View {
        Text(section.label)
            .font(.headline).foregroundColor(.black)
            .frame(minWidth: 32, minHeight: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(tint))
    }

    private var tips: some View {
        DisclosureGroup("How to spot a repeat") {
            VStack(alignment: .leading, spacing: 6) {
                Text("• Phrases are often 4 or 8 bars long. Compare the first bar of each phrase with the first bar of the piece.")
                Text("• Compare the endings too. The same start with a new ending usually means the phrase is being answered or closed.")
                Text("• Look at the shape of the notes (up, down, leaps) before reading names. The same shape is easy to see from far away.")
                Text("• Check the left hand on its own. A repeated pattern there often tells you a new section hasn't started yet.")
                Text("This view only marks notes that match exactly, so a tune repeated in another key is yours to find.")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        }
    }

    private func section(_ form: SongForm, _ section: SongForm.Section) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if form.hasRepeats {
                HStack(spacing: 10) {
                    letter(section, tint: tint(form, section))
                    Text(section.bars.count == 1 ? "Bar \(section.bars.upperBound)" : "Bars \(section.bars.lowerBound + 1)–\(section.bars.upperBound)")
                        .font(.subheadline.weight(.semibold))
                    Text(section.note).font(.subheadline).foregroundColor(.secondary)
                }
            }
            ForEach(lines(of: section), id: \.lowerBound) { line(form, section, bars: $0) }
        }
    }

    private func lines(of section: SongForm.Section) -> [Range<Int>] {
        stride(from: section.bars.lowerBound, to: section.bars.upperBound, by: Self.barsPerLine).map {
            $0..<min($0 + Self.barsPerLine, section.bars.upperBound)
        }
    }

    private func line(_ form: SongForm, _ section: SongForm.Section, bars: Range<Int>) -> some View {
        let starts = song.barStartBeats
        let ends = song.barlineBeats
        let lineBars = bars.map {
            StaffView.Line.Bar(number: $0 + 1, beats: starts[$0]..<ends[$0], isMarked: section.changedBars.contains($0))
        }
        // Short lines keep the width of a full one, so bars line up down the page.
        let beats = max(ends[bars.upperBound - 1] - starts[bars.lowerBound],
                        Double(Self.barsPerLine) * song.initialTimeSignature.beatsPerBar)
        return StaffView(song: song, scrollBeat: starts[bars.lowerBound], fitBeats: beats, showFingers: showFingers, soloClef: clef,
                         line: StaffView.Line(bars: lineBars, tint: tint(form, section), showsTimeSignature: bars.lowerBound == 0))
            .frame(height: Self.lineHeight)
            .allowsHitTesting(false)
    }
}
