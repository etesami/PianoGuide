import Foundation

/// Practice pieces cut from "Ghoghaye Setaregan" (music: Homayoun Khorram), a waltz in 3/4, for the guided paths.
/// The notes are **not** in the app: they come from the player's own MIDI file of the song, imported in the Paths sheet
/// (`file`), laid out like the user's arrangement (`ghoghaye_setaregan.py`: 116 bars of 3/4, bars 1–2 an intro, track 1 the
/// right hand, track 2 the left hand with a waltz: low note on 1, a two-note chord on 2 and 3; fingers as lyrics).
/// "Two Hands Together" uses the verse (bars 3–26), "Setaregan: Second Half" the rest.
/// Each hand comes in easier versions, made from the file's notes, so the hands can meet a little at a time:
/// the left hand plays only its low note, then the low note and one chord, then the full waltz ("oom-pah-pah");
/// the right hand plays the melody, or just its first note in each bar, held.
public enum SetaregaanPiece {
    /// Parts of the song. Bars are the score's.
    public enum Section: String, CaseIterable, Sendable {
        // The verse (first path). Every part starts with the pickup "rest, E, F".
        /// Score bars 3–10: G F, G F, G E, twice.
        case first
        /// Score bars 11–18: up to A, then the run C B A G F, twice.
        case second
        /// Score bars 19–26: like the first, with new turns.
        case third
        /// Score bars 3–26.
        case verse

        // The second half (second path).
        /// Score bars 27–34: repeated notes C C C, B B B, A A A, with the hand up in F position.
        case chorus
        /// Score bars 35–44: the melody climbs G A B C; the left hand gets a new chord, G.
        case climb
        /// Score bars 45–52: back down A G F E, twice, in the old thumb-on-E place.
        case comeDown
        /// Score bars 53–60: the verse's last section again.
        case verseAgain
        /// Score bars 27–60: chorus, climb, come down and verse in one go.
        case middle
        /// Score bars 61–70: the hand moves up to G position; two long tied notes.
        case gPosition
        /// Score bars 71–78: long held notes over an E minor waltz.
        case longNotes
        /// Score bars 79–92: the highest part, up to E5 in A position (played twice in the song).
        case high
        /// Score bars 107–116: the verse tune once more and the last long E.
        case ending
        /// Score bars 61–116.
        case finale
        /// Score bars 27–116.
        case secondHalf
        /// Score bars 3–116: the whole song.
        case whole

        var bars: ClosedRange<Int> {
            switch self {
            case .first: 3...10
            case .second: 11...18
            case .third: 19...26
            case .verse: 3...26
            case .chorus: 27...34
            case .climb: 35...44
            case .comeDown: 45...52
            case .verseAgain: 53...60
            case .middle: 27...60
            case .gPosition: 61...70
            case .longNotes: 71...78
            case .high: 79...92
            case .ending: 107...116
            case .finale: 61...116
            case .secondHalf: 27...116
            case .whole: 3...116
            }
        }

        public var barCount: Int { bars.count }
        /// The first and last score bar.
        public var firstBar: Int { bars.lowerBound }
        public var lastBar: Int { bars.upperBound }

        public var name: String {
            switch self {
            case .first: "Section 1"
            case .second: "Section 2"
            case .third: "Section 3"
            case .verse: "Verse"
            case .chorus: "Chorus"
            case .climb: "The climb"
            case .comeDown: "Coming down"
            case .verseAgain: "Verse again"
            case .middle: "Bars 27–60"
            case .gPosition: "G position"
            case .longNotes: "Long notes"
            case .high: "The high part"
            case .ending: "The ending"
            case .finale: "Bars 61–116"
            case .secondHalf: "Second half"
            case .whole: "Whole song"
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

    /// The song's length in score bars.
    public static let barCount = 116

    /// The file the Setaregan paths are built from.
    public static let file = PathSongFile(
        id: "ghoghaye-setaregan",
        songName: "Ghoghaye Setaregan",
        hint: """
            Import your MIDI file of Ghoghaye Setaregan ("Ghoghaye Setaregan.mid", made by ghoghaye_setaregan.py): \
            116 bars of 3/4, the right hand on the first track and the left hand on the second.
            """,
        check: problem)

    /// Nil when `song` is laid out like the arrangement the paths are written for, else why not.
    @Sendable public static func problem(with song: Song) -> String? {
        guard let time = song.timeSignatures.first, time.numerator == 3, time.denominator == 4 else {
            return "It isn't in 3/4 time."
        }
        guard song.notes.contains(where: { $0.hand == .right }), song.notes.contains(where: { $0.hand == .left }) else {
            return "It needs two tracks: the right hand first, then the left hand."
        }
        // Notes are written a little short (95%), so the last bar is the one the last note ends in.
        let end = song.notes.map { $0.startBeat + $0.durationBeats }.max() ?? 0
        let bars = Int((end / beatsPerBar).rounded(.up))
        guard bars == barCount else { return "It has \(bars) bars; the paths need the \(barCount)-bar arrangement." }
        return nil
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

    /// One part of `source` (the imported song), both hands, 3/4, with the file's fingers and tempo.
    /// A note held out of the part's last bar is cut at the end of the part.
    public static func song(_ section: Section, from source: Song, left: Left = .full, right: Right = .melody) -> Song {
        let eps = 1e-6
        let offset = Double(section.firstBar - 1) * beatsPerBar
        let length = Double(section.barCount) * beatsPerBar
        var notes: [NoteEvent] = source.notes.compactMap { n in
            let start = n.startBeat - offset
            guard start > -eps, start < length - eps else { return nil }
            var note = n
            note.startBeat = start
            note.durationBeats = min(n.durationBeats, (length - start) * 0.95)
            return note
        }
        func barStart(_ n: NoteEvent) -> Double { floor((n.startBeat + eps) / beatsPerBar) * beatsPerBar }
        func at(_ n: NoteEvent, beat: Double) -> Bool { abs(n.startBeat - barStart(n) - beat) < eps }

        switch left {
        case .full:
            break
        case .root:
            // The lowest note on each downbeat, held at least the whole bar.
            var lowest: [Double: NoteEvent] = [:]
            for n in notes where n.hand == .left && at(n, beat: 0) {
                if let other = lowest[n.startBeat], other.pitch <= n.pitch { continue }
                lowest[n.startBeat] = n
            }
            notes.removeAll { $0.hand == .left }
            for var n in lowest.values {
                n.durationBeats = min(max(n.durationBeats, beatsPerBar * 0.95), (length - n.startBeat) * 0.95)
                notes.append(n)
            }
        case .rootAndChord:
            // The downbeat as it is, the chord on 2 held through 3, nothing on 3.
            notes = notes.compactMap { n in
                guard n.hand == .left, !at(n, beat: 0) else { return n }
                guard at(n, beat: 1) else { return nil }
                var chord = n
                chord.durationBeats = 2 * 0.95
                return chord
            }
        }
        if right == .firstNotes {
            // The first note starting in each bar, held to the end of the bar.
            var firsts: [Double: NoteEvent] = [:]
            for n in notes where n.hand == .right {
                let bar = barStart(n)
                if let other = firsts[bar], (other.startBeat, other.pitch) <= (n.startBeat, n.pitch) { continue }
                firsts[bar] = n
            }
            notes.removeAll { $0.hand == .right }
            for var n in firsts.values {
                n.durationBeats = (barStart(n) + beatsPerBar - n.startBeat) * 0.95
                notes.append(n)
            }
        }
        let sorted = notes.sorted { ($0.startBeat, $0.pitch) < ($1.startBeat, $1.pitch) }
        let bpm = source.bpm(atBeat: offset)
        return Song(title: title(section, left: left, right: right),
                    tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: Int((60_000_000 / bpm).rounded()))],
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
