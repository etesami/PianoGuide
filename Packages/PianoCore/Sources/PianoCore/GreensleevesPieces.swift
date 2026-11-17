import Foundation

/// Practice pieces made from "Greensleeves (simple)" (the user's file `Greensleeves (simple).mid`), A minor, 3/4 at 72 BPM,
/// 31 bars with a one-note pickup, for the "Moving Hand" guided path. Notes and fingers follow the file.
/// The left hand is the same shape in every bar (low note with 5 held two beats, the fifth above with 1 on beat 3);
/// the work is in the right hand, which changes position often and has a dotted "lilt". So each hand comes in an easier
/// version: the right hand with the dots taken out (every note on a beat), the left hand as one long low note per bar.
public enum GreensleevesPiece {
    public enum Section: String, CaseIterable, Sendable {
        /// Bars 1–9: the pickup and the first phrase (ends on E, without the next pickup).
        case first
        /// Bars 1–16: the first phrase twice, the second time with the F♯–G♯ ending.
        case verse
        /// Bars 16–31: from the verse's last note up to the high G, twice, with the same ending.
        case refrain
        /// Bars 1–31.
        case whole

        var bars: ClosedRange<Int> {
            switch self {
            case .first: 1...9
            case .verse: 1...16
            case .refrain: 16...31
            case .whole: 1...31
            }
        }

        public var barCount: Int { bars.count }

        public var name: String {
            switch self {
            case .first: "Phrase 1"
            case .verse: "Verse"
            case .refrain: "Refrain"
            case .whole: "Whole song"
            }
        }
    }

    public enum Right: Sendable {
        /// The real melody, with its dotted rhythm.
        case melody
        /// The same notes with the dots taken out: a dotted quarter and its eighth become two quarters.
        case even
    }

    public enum Left: Sendable {
        /// One low note per bar, held for the whole bar.
        case root
        /// The real part: the low note held two beats, the fifth above on beat 3.
        case full
    }

    public static let beatsPerBar = 3.0
    public static let bpm = 72

    /// Right hand per bar: "pitch/finger:beats", "r:beats" is a rest. Fingers as in the file.
    private static let melody: [Int: String] = {
        var bars: [Int: String] = [
            1: "r:2 A4/1:1",
            2: "C5/2:2 D5/3:1", 3: "E5/4:1.5 F5/5:.5 E5/4:1", 4: "D5/3:2 B4/2:1", 5: "G4/1:1.5 A4/3:.5 B4/4:1",
            6: "C5/5:2 A4/3:1", 7: "A4/3:1.5 G#4/2:.5 A4/3:1", 8: "B4/4:2 G#4/2:1", 9: "E4/1:2 A4/1:1",
            14: "C5/5:1.5 B4/4:.5 A4/3:1", 15: "G#4/2:1.5 F#4/1:.5 G#4/2:1", 16: "A4/3:3",
            17: "G5/5:3", 18: "G5/5:1.5 F#5/4:.5 E5/3:1", 19: "D5/2:2 B4/1:1", 24: "E4/1:3",
        ]
        for bar in 10...13 { bars[bar] = bars[bar - 8] }
        for bar in 20...23 { bars[bar] = bars[bar - 15] }
        for bar in 25...28 { bars[bar] = bars[bar - 8] }
        for bar in 29...31 { bars[bar] = bars[bar - 15] }
        return bars
    }()

    /// Left-hand chord letter per bar (index 0 = bar 1, which has none): A = A2+E3, C = C3+G3, G = G2+D3, E = E3+B3.
    private static let chords = Array("-ACGEAEEA" + "ACGEAEA" + "GGGEAEEE" + "GGGEAEA")

    private static func fifth(bar: Int) -> (root: String, fifth: String)? {
        switch chords[bar - 1] {
        case "A": ("A2", "E3")
        case "C": ("C3", "G3")
        case "G": ("G2", "D3")
        case "E": ("E3", "B3")
        default: nil
        }
    }

    public static func title(_ section: Section, right: Right, left: Left) -> String {
        "Greensleeves · \(section.name) · " + (right == .melody ? "melody" : "even melody")
            + (left == .full ? " + fifths" : " + low notes")
    }

    /// One part of the song, both hands, 3/4 at 72 BPM, with the finger on every note.
    public static func song(_ section: Section, right: Right = .melody, left: Left = .full) -> Song {
        var notes: [NoteEvent] = []
        func add(_ name: String, finger: Int, at beat: Double, beats: Double, hand: Hand) {
            notes.append(NoteEvent(id: 0, pitch: StaffExample.pitch(Substring(name))!, startBeat: beat, durationBeats: beats * 0.95,
                                   velocity: hand == .right ? 85 : 55, hand: hand, finger: finger))
        }
        for (i, bar) in section.bars.enumerated() {
            let start = Double(i) * beatsPerBar
            let last = bar == section.bars.upperBound
            // Right hand. A section that ends on bar 9 holds its E instead of playing the next phrase's pickup.
            var items = melody[bar]!.split(separator: " ").map { item -> (String, Double) in
                let parts = item.split(separator: ":")
                return (String(parts[0]), Double(parts[1])!)
            }
            if last && bar == 9 { items = [(items[0].0, 3)] }
            if right == .even {
                // Dotted quarter + eighth → quarter + quarter.
                items = items.map { $0.1 == 1.5 ? ($0.0, 1) : $0.1 == 0.5 ? ($0.0, 1) : $0 }
            }
            var beat = start
            for (spec, length) in items {
                defer { beat += length }
                guard spec != "r" else { continue }
                let note = spec.split(separator: "/")
                add(String(note[0]), finger: Int(note[1])!, at: beat, beats: length, hand: .right)
            }
            // Left hand. The song's last bar holds the open fifth together.
            guard let (root, fifth) = fifth(bar: bar) else { continue }
            switch left {
            case .root:
                add(root, finger: 5, at: start, beats: 3, hand: .left)
            case .full where bar == 31:
                add(root, finger: 5, at: start, beats: 3, hand: .left)
                add(fifth, finger: 1, at: start, beats: 3, hand: .left)
            case .full:
                add(root, finger: 5, at: start, beats: 2, hand: .left)
                add(fifth, finger: 1, at: start + 2, beats: 1, hand: .left)
            }
        }
        let sorted = notes.sorted { ($0.startBeat, $0.pitch) < ($1.startBeat, $1.pitch) }
        return Song(title: title(section, right: right, left: left),
                    tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: 60_000_000 / bpm)],
                    timeSignatures: [TimeSignature(beat: 0, numerator: 3, denominator: 4)],
                    notes: sorted.enumerated().map { i, n in
                        NoteEvent(id: i, pitch: n.pitch, startBeat: n.startBeat, durationBeats: n.durationBeats,
                                  velocity: n.velocity, hand: n.hand, finger: n.finger)
                    })
    }
}
