import PianoCore
import SwiftUI

/// Sheet with the lesson note for a practice, shown after the practice is picked: text plus short music examples
/// on the grand staff (key notes in blue). Scrolls if it is long;
/// the user closes it with "Start Practice" (or by swiping it down).
struct PracticeNoteView: View {
    let note: PracticeNote
    let songName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(note.blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .heading(let text):
                            Text(Self.inline(text)).font(.headline).padding(.top, 8)
                        case .paragraph(let text):
                            Text(Self.inline(text))
                        case .bullet(let text):
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•")
                                Text(Self.inline(text))
                            }
                        case .staff(let example):
                            StaffExampleView(example: example)
                        case .invalidStaff(let reason):
                            Label("Music example can't be shown: \(reason)", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundColor(.orange)
                        }
                    }
                }
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(note.title ?? songName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Practice") { dismiss() }
                }
            }
        }
    }

    /// Renders `**bold**`, `*italic*` and the like; falls back to the plain text.
    private static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

/// A lesson note's music example: a still grand staff showing whole bars, highlighted notes in blue,
/// and an optional caption below.
struct StaffExampleView: View {
    let example: StaffExample

    var body: some View {
        let song = example.song
        let barBeats = example.timeSignature.beatsPerBar
        let bars = max(1, (song.durationBeats / barBeats - 1e-6).rounded(.up))
        VStack(alignment: .leading, spacing: 6) {
            StaffView(song: song,
                      noteStates: Dictionary(uniqueKeysWithValues: example.highlighted.map { ($0, .next) }),
                      scrollBeat: 0,
                      fitBeats: bars * barBeats)
                .frame(maxWidth: 120 + bars * 240)
                .frame(height: 200)
            if let caption = example.caption {
                Text(caption).font(.callout).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
