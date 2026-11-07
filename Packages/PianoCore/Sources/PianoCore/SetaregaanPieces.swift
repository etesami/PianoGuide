import Foundation

/// Practice pieces made from the verse of "Ghoghaye Setaregan" (music: Homayoun Khorram), a waltz in 3/4 at 100 BPM,
/// for the two-hands guided path. The notes follow the user's own arrangement (`ghoghaye_setaregan.py`, score bars 3–26).
/// Each hand comes in easier versions, so the hands can meet a little at a time:
/// the left hand plays only its low note, then the low note and one chord, then the full waltz ("oom-pah-pah");
/// the right hand plays the melody, or just its first note in each bar, held.
public enum SetaregaanPiece {
    /// Parts of the verse. Bars are the score's; every part starts with the pickup "rest, E, F".
    public enum Section: String, CaseIterable, Sendable {
        /// Score bars 3–10: G F, G F, G E, twice.
        case first
        /// Score bars 11–18: up to A, then the run C B A G F, twice.
        case second
        /// Score bars 19–26: like the first, with new turns.
        case third
        /// Score bars 3–26.
        case verse

        var bars: ClosedRange<Int> {
            switch self {
            case .first: 3...10
            case .second: 11...18
            case .third: 19...26
            case .verse: 3...26
            }
        }

        public var barCount: Int { bars.count }

        public var name: String {
            switch self {
            case .first: "Section 1"
            case .second: "Section 2"
            case .third: "Section 3"
            case .verse: "Verse"
            }
        }
    }

    public enum Left: Sendable {
        /// One low note per bar, held for the whole bar.
        case root
        /// The low note on beat 1, then the chord on beat 2, held through beat 3.
        case rootAndChord
        /// The waltz: the low note on 1, the chord on 2 and again on 3.
        case full
    }

    public enum Right: Sendable {
        /// The real melody.
        case melody
        /// Only the first note of each bar, held to the end of the bar.
        case firstNotes
    }

    public static let beatsPerBar = 3.0
    public static let bpm = 100

    /// Right hand, score bars 3–26: "pitch/finger:beats", "r:beats" is a rest. Thumb on E (E 1, F 2, G 3, A 4, B 5);
    /// in bars 13 and 17 the hand moves up one key (C with 5) for the run, and the thumb slides back from F to E after it.
    private static let melody: [Int: String] = {
        let pickup = "r:1 E4/1:1 F4/2:1"
        var bars: [Int: String] = [
            3: pickup, 4: "G4/3:1 F4/2:2", 5: "G4/3:1 F4/2:2", 6: "G4/3:1 E4/1:2",
            12: "G4/3:1 A4/4:2", 13: "C5/5:1 B4/4:.5 A4/3:.5 G4/2:.5 F4/1:.5", 14: "E4/1:2 r:1",
            20: "G4/3:1 F4/2:2", 21: "G4/3:1 A4/4:2", 22: "F4/2:1 E4/1:2",
            24: "G4/3:1 F4/2:1 r:1",
        ]
        for bar in [7, 11, 15, 19, 23] { bars[bar] = pickup }
        for bar in 8...10 { bars[bar] = bars[bar - 4] }
        for bar in 16...18 { bars[bar] = bars[bar - 4] }
        bars[25] = bars[21]
        bars[26] = bars[22]
        return bars
    }()

    /// Left-hand chord per score bar (from the chord symbols); the rest are E minor.
    private static func chord(bar: Int) -> (root: (String, Int), upper: [(String, Int)]) {
        let fBars: Set<Int> = [4, 5, 8, 9, 13, 17, 20, 21, 24, 25]
        let amBars: Set<Int> = [12, 16]
        if fBars.contains(bar) { return (("F3", 5), [("A3", 3), ("C4", 1)]) }
        if amBars.contains(bar) { return (("E3", 5), [("A3", 2), ("C4", 1)]) }
        return (("E3", 5), [("G3", 3), ("B3", 1)])
    }

    public static func title(_ section: Section, left: Left, right: Right) -> String {
        let l: String
        switch left {
        case .root: l = "low notes"
        case .rootAndChord: l = "low note + chord"
        case .full: l = "waltz"
        }
        return "Setaregan · \(section.name) · " + (right == .melody ? "melody" : "long notes") + " + \(l)"
    }

    /// One part of the verse, both hands, 3/4 at 100 BPM, with the finger on every note.
    public static func song(_ section: Section, left: Left = .full, right: Right = .melody) -> Song {
        var notes: [NoteEvent] = []
        func add(_ name: String, finger: Int, at beat: Double, beats: Double, hand: Hand) {
            notes.append(NoteEvent(id: 0, pitch: pitch(name), startBeat: beat, durationBeats: beats * 0.95,
                                   velocity: hand == .right ? 85 : 60, hand: hand, finger: finger))
        }
        for (i, bar) in section.bars.enumerated() {
            let start = Double(i) * beatsPerBar
            // Right hand.
            var beat = start
            var first = true
            for item in melody[bar]!.split(separator: " ") {
                let parts = item.split(separator: ":")
                let length = Double(parts[1])!
                defer { beat += length }
                guard parts[0] != "r" else { continue }
                let note = parts[0].split(separator: "/")
                if right == .melody {
                    add(String(note[0]), finger: Int(note[1])!, at: beat, beats: length, hand: .right)
                } else if first {
                    add(String(note[0]), finger: Int(note[1])!, at: beat, beats: start + beatsPerBar - beat, hand: .right)
                }
                first = false
            }
            // Left hand.
            let (root, upper) = chord(bar: bar)
            switch left {
            case .root:
                add(root.0, finger: root.1, at: start, beats: 3, hand: .left)
            case .rootAndChord:
                add(root.0, finger: root.1, at: start, beats: 1, hand: .left)
                for (name, finger) in upper { add(name, finger: finger, at: start + 1, beats: 2, hand: .left) }
            case .full:
                add(root.0, finger: root.1, at: start, beats: 1, hand: .left)
                for offset in [1.0, 2.0] {
                    for (name, finger) in upper { add(name, finger: finger, at: start + offset, beats: 1, hand: .left) }
                }
            }
        }
        let sorted = notes.sorted { ($0.startBeat, $0.pitch) < ($1.startBeat, $1.pitch) }
        return Song(title: title(section, left: left, right: right),
                    tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: 60_000_000 / bpm)],
                    timeSignatures: [TimeSignature(beat: 0, numerator: 3, denominator: 4)],
                    notes: sorted.enumerated().map { i, n in
                        NoteEvent(id: i, pitch: n.pitch, startBeat: n.startBeat, durationBeats: n.durationBeats,
                                  velocity: n.velocity, hand: n.hand, finger: n.finger)
                    })
    }

    /// "C4" → 60, "F#3" → 54.
    static func pitch(_ name: String) -> UInt8 {
        let steps: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        let octave = Int(String(name.last!))!
        let sharp = name.contains("#") ? 1 : 0
        return UInt8(12 * (octave + 1) + steps[name.first!]! + sharp)
    }
}
