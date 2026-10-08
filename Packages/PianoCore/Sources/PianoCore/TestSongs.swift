import Foundation

/// Songs for trying the import in the app (written to `TestSongs/` by `write-samples --test-songs`).
/// Each one covers something the bundled "Twinkle" sample doesn't.
public enum TestSongs {
    /// File name (without `.mid`) → song, and whether it is written as a single track (format 0).
    public static var all: [(name: String, song: Song, singleTrack: Bool)] {
        [("Ode to Joy", odeToJoy, false), ("Minuet in G", minuetInG, true)]
    }

    /// Beethoven, "Ode to Joy" (8 bars, 4/4, 100 BPM). Two tracks (right hand, left hand),
    /// three-note left-hand chords on every half bar, and a dotted quarter + eighth in bars 4 and 8.
    public static var odeToJoy: Song {
        let (C4, D4, E4, F4, G4): (UInt8, UInt8, UInt8, UInt8, UInt8) = (60, 62, 64, 65, 67)
        let phrase: [(UInt8, Double)] = [(E4, 1), (E4, 1), (F4, 1), (G4, 1), (G4, 1), (F4, 1), (E4, 1), (D4, 1),
                                         (C4, 1), (C4, 1), (D4, 1), (E4, 1)]
        let ending1: [(UInt8, Double)] = [(E4, 1.5), (D4, 0.5), (D4, 2)]
        let ending2: [(UInt8, Double)] = [(D4, 1.5), (C4, 0.5), (C4, 2)]
        let melody = phrase + ending1 + phrase + ending2

        let cMajor: [UInt8] = [48, 52, 55]   // C3 E3 G3
        let gMajor: [UInt8] = [43, 47, 50]   // G2 B2 D3
        let chords: [[UInt8]] = [cMajor, cMajor, gMajor, gMajor, cMajor, cMajor, gMajor, gMajor,
                                 cMajor, cMajor, gMajor, gMajor, cMajor, cMajor, gMajor, cMajor]
        var notes = sequence(melody, hand: .right, velocity: 85)
        for (i, chord) in chords.enumerated() {
            for pitch in chord {
                notes.append(NoteEvent(id: 0, pitch: pitch, startBeat: Double(i * 2), durationBeats: 1.9,
                                       velocity: 65, hand: .left))
            }
        }
        return Song(title: "Ode to Joy", tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: 600_000)],
                    timeSignatures: [TimeSignature(beat: 0, numerator: 4, denominator: 4)], notes: numbered(notes))
    }

    /// Petzold, Minuet in G (first 8 bars, simplified left hand), 3/4. Written as a **single track**,
    /// so the app has to split the hands at middle C. Eighth notes, an F#, and a slow-down
    /// (100 → 80 BPM) for the last two bars.
    public static var minuetInG: Song {
        let (G4, A4, B4, C5, D5, E5, Fs5, G5, Fs4): (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (67, 69, 71, 72, 74, 76, 78, 79, 66)
        let melody: [(UInt8, Double)] = [
            (D5, 1), (G4, 0.5), (A4, 0.5), (B4, 0.5), (C5, 0.5),
            (D5, 1), (G4, 1), (G4, 1),
            (E5, 1), (C5, 0.5), (D5, 0.5), (E5, 0.5), (Fs5, 0.5),
            (G5, 1), (G4, 1), (G4, 1),
            (C5, 1), (D5, 0.5), (C5, 0.5), (B4, 0.5), (A4, 0.5),
            (B4, 1), (C5, 0.5), (B4, 0.5), (A4, 0.5), (G4, 0.5),
            (Fs4, 1), (G4, 0.5), (A4, 0.5), (B4, 0.5), (G4, 0.5),
            (A4, 3),
        ]
        // Left hand, all below middle C. Bar 1 starts with a two-note chord (G3 + B3).
        let bass: [([UInt8], Double)] = [
            ([55, 59], 2), ([57], 1),          // G3+B3, A3
            ([59], 3),                         // B3
            ([48], 3),                         // C3
            ([47], 3),                         // B2
            ([45], 3),                         // A2
            ([43], 3),                         // G2
            ([50], 1), ([47], 1), ([43], 1),   // D3 B2 G2
            ([50], 2), ([38], 1),              // D3, D2
        ]
        var notes = sequence(melody, hand: .right, velocity: 85)
        var beat = 0.0
        for (pitches, length) in bass {
            for pitch in pitches {
                notes.append(NoteEvent(id: 0, pitch: pitch, startBeat: beat, durationBeats: length * 0.95,
                                       velocity: 65, hand: .left))
            }
            beat += length
        }
        return Song(title: "Minuet in G",
                    tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: 600_000),
                               TempoChange(beat: 18, microsecondsPerQuarter: 750_000)],
                    timeSignatures: [TimeSignature(beat: 0, numerator: 3, denominator: 4)], notes: numbered(notes))
    }

    /// Notes one after another; each sounds for 95% of its length so repeated notes stay separate.
    private static func sequence(_ notes: [(UInt8, Double)], hand: Hand, velocity: UInt8) -> [NoteEvent] {
        var out: [NoteEvent] = []
        var beat = 0.0
        for (pitch, length) in notes {
            out.append(NoteEvent(id: 0, pitch: pitch, startBeat: beat, durationBeats: length * 0.95,
                                 velocity: velocity, hand: hand))
            beat += length
        }
        return out
    }

    /// Sorts by start and pitch and sets `id` to the index, as `Song.notes` expects.
    private static func numbered(_ notes: [NoteEvent]) -> [NoteEvent] {
        notes.sorted { ($0.startBeat, $0.pitch) < ($1.startBeat, $1.pitch) }.enumerated().map { i, n in
            NoteEvent(id: i, pitch: n.pitch, startBeat: n.startBeat, durationBeats: n.durationBeats,
                      velocity: n.velocity, hand: n.hand)
        }
    }
}
