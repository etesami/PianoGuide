import Foundation

/// A practice piece cut out of a whole song by score bars, for paths written as plan files (`PathPlan`), with easier
/// versions of each hand made from the song's own notes, so the hands can meet a little at a time:
/// the left hand plays only its low note, then the low note and its chord, then everything;
/// the right hand plays the melody, or just its first note in each bar, held.
/// Works for a left hand laid out as "low note on 1, chord after it" (waltz, oom-pah); other layouts still work but the
/// easier versions say less.
public enum PathPiece {
    public enum Left: String, CaseIterable, Sendable {
        /// Everything as written.
        case full
        /// The lowest note on each downbeat, held at least the whole bar.
        case lowNotes = "low notes"
        /// The downbeat as written, the notes on beat 2 held to the end of the bar, nothing after them.
        case lowNoteAndChord = "low note + chord"
    }

    public enum Right: String, CaseIterable, Sendable {
        /// Everything as written.
        case melody
        /// The first note starting in each bar, held to the end of the bar.
        case longNotes = "long notes"
    }

    /// Beats (quarter notes) per bar of `song`'s first time signature.
    public static func beatsPerBar(_ song: Song) -> Double {
        song.timeSignatures.first.map(\.beatsPerBar) ?? 4
    }

    /// Score bars `bars` (1-based) of `source`, both hands, with the source's fingers and tempo.
    /// A note held out of the last bar is cut at the end of the piece.
    public static func song(from source: Song, bars: ClosedRange<Int>, left: Left = .full, right: Right = .melody,
                            title: String) -> Song {
        let eps = 1e-6
        let perBar = beatsPerBar(source)
        let offset = Double(bars.lowerBound - 1) * perBar
        let length = Double(bars.count) * perBar
        var notes: [NoteEvent] = source.notes.compactMap { n in
            let start = n.startBeat - offset
            guard start > -eps, start < length - eps else { return nil }
            var note = n
            note.startBeat = start
            note.durationBeats = min(n.durationBeats, (length - start) * 0.95)
            return note
        }
        func barStart(_ n: NoteEvent) -> Double { floor((n.startBeat + eps) / perBar) * perBar }
        func at(_ n: NoteEvent, beat: Double) -> Bool { abs(n.startBeat - barStart(n) - beat) < eps }

        switch left {
        case .full:
            break
        case .lowNotes:
            var lowest: [Double: NoteEvent] = [:]
            for n in notes where n.hand == .left && at(n, beat: 0) {
                if let other = lowest[n.startBeat], other.pitch <= n.pitch { continue }
                lowest[n.startBeat] = n
            }
            notes.removeAll { $0.hand == .left }
            for var n in lowest.values {
                n.durationBeats = min(max(n.durationBeats, perBar * 0.95), (length - n.startBeat) * 0.95)
                notes.append(n)
            }
        case .lowNoteAndChord:
            notes = notes.compactMap { n in
                guard n.hand == .left, !at(n, beat: 0) else { return n }
                guard at(n, beat: 1) else { return nil }
                var chord = n
                chord.durationBeats = (perBar - 1) * 0.95
                return chord
            }
        }
        if right == .longNotes {
            var firsts: [Double: NoteEvent] = [:]
            for n in notes where n.hand == .right {
                let bar = barStart(n)
                if let other = firsts[bar], (other.startBeat, other.pitch) <= (n.startBeat, n.pitch) { continue }
                firsts[bar] = n
            }
            notes.removeAll { $0.hand == .right }
            for var n in firsts.values {
                n.durationBeats = (barStart(n) + perBar - n.startBeat) * 0.95
                notes.append(n)
            }
        }
        let sorted = notes.sorted { ($0.startBeat, $0.pitch) < ($1.startBeat, $1.pitch) }
        let time = source.timeSignatures.first ?? TimeSignature(beat: 0, numerator: 4, denominator: 4)
        let bpm = source.bpm(atBeat: offset)
        return Song(title: title,
                    tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: Int((60_000_000 / bpm).rounded()))],
                    timeSignatures: [TimeSignature(beat: 0, numerator: time.numerator, denominator: time.denominator)],
                    notes: sorted.enumerated().map { i, n in
                        NoteEvent(id: i, pitch: n.pitch, startBeat: n.startBeat, durationBeats: n.durationBeats,
                                  velocity: n.velocity, hand: n.hand, finger: n.finger)
                    })
    }
}
