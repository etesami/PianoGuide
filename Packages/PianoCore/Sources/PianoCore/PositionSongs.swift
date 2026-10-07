import Foundation

/// Five-finger positions: finger (1 = thumb … 5 = little finger) → key, per hand.
/// F position skips the B♭ (right-hand finger 4, left-hand finger 2) because the staff can't show flats yet.
public enum FivePosition: String, CaseIterable, Sendable {
    case c = "C", f = "F", d = "D"

    public func pitch(finger: Int, hand: Hand) -> UInt8 {
        // Keys for fingers 1…5 of the right hand; the left hand uses the same five keys an octave
        // lower, played from the other side (left-hand 5 is the lowest key).
        let rightHand: [UInt8]
        switch self {
        case .c: rightHand = [60, 62, 64, 65, 67]   // C4 D4 E4 F4 G4
        case .f: rightHand = [65, 67, 69, 70, 72]   // F4 G4 A4 (B♭4) C5
        case .d: rightHand = [62, 64, 66, 67, 69]   // D4 E4 F#4 G4 A4
        }
        let lowShift: UInt8 = self == .f ? 24 : 12  // F position's left hand sits on F2 so it stays below C3…C4
        return hand == .left ? rightHand[5 - finger] - lowShift : rightHand[finger - 1]
    }
}

extension SampleSongs {
    /// Right hand only: C position (bars 1–4), F (5–8), D (9–12), back to C (13–16). 4/4, 90 BPM.
    /// The first note of each bar shows its finger number.
    public static var positionsRightHand: Song {
        let phrase: [[(finger: Int, beats: Double)]] = [
            [(1, 1), (2, 1), (3, 1), (4, 1)],
            [(5, 1), (4, 1), (3, 1), (2, 1)],
            [(1, 1), (3, 1), (5, 1), (3, 1)],
            [(1, 4)],
        ]
        // F position has no finger 4 (B♭), so its phrase avoids it.
        let fPhrase: [[(finger: Int, beats: Double)]] = [
            [(1, 1), (2, 1), (3, 1), (2, 1)],
            [(1, 1), (3, 1), (5, 1), (3, 1)],
            [(5, 1), (3, 1), (2, 1), (3, 1)],
            [(1, 4)],
        ]
        var builder = PositionSongBuilder()
        for position in [FivePosition.c, .f, .d, .c] {
            for bar in position == .f ? fPhrase : phrase {
                builder.bar(right: bar, left: [], in: position)
            }
        }
        return builder.song(title: "Positions C-F-D (right hand)")
    }

    /// Both hands, in turns: right hand, then left hand, then right hand, then both together on a whole note.
    /// The left hand uses fingers 5, 4, 3 only, so F position needs no B♭.
    /// Same positions as `positionsRightHand` (C, F, D, C). The first note of each bar in each hand shows its finger.
    public static var positionsBothHands: Song {
        var builder = PositionSongBuilder()
        for position in [FivePosition.c, .f, .d, .c] {
            builder.bar(right: [(1, 1), (2, 1), (3, 1), (2, 1)], left: [], in: position)
            builder.bar(right: [], left: [(5, 1), (4, 1), (3, 1), (4, 1)], in: position)
            builder.bar(right: [(1, 1), (3, 1), (5, 1), (3, 1)], left: [], in: position)
            builder.bar(right: [(1, 4)], left: [(5, 4)], in: position)
        }
        return builder.song(title: "Positions C-F-D (both hands)")
    }
}

/// Builds a 4/4 song bar by bar from finger numbers.
struct PositionSongBuilder {
    private var notes: [NoteEvent] = []
    private var barStart = 0.0

    mutating func bar(right: [(finger: Int, beats: Double)], left: [(finger: Int, beats: Double)],
                      in position: FivePosition) {
        for (hand, fingers) in [(Hand.right, right), (.left, left)] {
            var beat = barStart
            for (i, item) in fingers.enumerated() {
                notes.append(NoteEvent(id: 0, pitch: position.pitch(finger: item.finger, hand: hand),
                                       startBeat: beat, durationBeats: item.beats * 0.95,
                                       velocity: hand == .right ? 85 : 70, hand: hand,
                                       finger: i == 0 ? item.finger : nil))
                beat += item.beats
            }
        }
        barStart += 4
    }

    func song(title: String) -> Song {
        let sorted = notes.sorted { ($0.startBeat, $0.pitch) < ($1.startBeat, $1.pitch) }
        return Song(title: title, tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: 666_667)],
                    timeSignatures: [TimeSignature(beat: 0, numerator: 4, denominator: 4)],
                    notes: sorted.enumerated().map { i, n in
                        NoteEvent(id: i, pitch: n.pitch, startBeat: n.startBeat, durationBeats: n.durationBeats,
                                  velocity: n.velocity, hand: n.hand, finger: n.finger)
                    })
    }
}
