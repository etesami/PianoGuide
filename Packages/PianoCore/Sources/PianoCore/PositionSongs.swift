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

/// One practice in the positions series: each one adds a position to the one before.
public struct PositionPractice: Sendable {
    public var number: Int
    /// Positions in the order they are learned; the practice plays them in turn, then returns to C.
    public var positions: [FivePosition]

    /// 1. C, 2. C + F, 3. C + F + D.
    public static let series: [PositionPractice] = [
        PositionPractice(number: 1, positions: [.c]),
        PositionPractice(number: 2, positions: [.c, .f]),
        PositionPractice(number: 3, positions: [.c, .f, .d]),
    ]

    /// "1. C position", "2. C + F positions", "3. C + F + D positions".
    public var name: String {
        "\(number). " + positions.map(\.rawValue).joined(separator: " + ")
            + (positions.count == 1 ? " position" : " positions")
    }

    /// The order the positions are played: each in turn, then back to C (C alone is played twice).
    var route: [FivePosition] { positions + [.c] }

    /// Right hand only, 8 bars per position (two 4-bar phrases), 4/4, 90 BPM.
    /// The first note of each bar shows its finger number.
    public var rightHand: Song {
        // F position has no finger 4 (B♭), so its phrases avoid it.
        let phrases: [[(finger: Int, beats: Double)]] = [
            [(1, 1), (2, 1), (3, 1), (4, 1)],
            [(5, 1), (4, 1), (3, 1), (2, 1)],
            [(1, 1), (3, 1), (5, 1), (3, 1)],
            [(1, 4)],
            [(3, 1), (4, 1), (5, 2)],
            [(5, 1), (3, 1), (4, 1), (2, 1)],
            [(3, 1), (2, 1), (1, 1), (2, 1)],
            [(1, 4)],
        ]
        let fPhrases: [[(finger: Int, beats: Double)]] = [
            [(1, 1), (2, 1), (3, 1), (2, 1)],
            [(1, 1), (3, 1), (5, 1), (3, 1)],
            [(5, 1), (3, 1), (2, 1), (3, 1)],
            [(1, 4)],
            [(1, 1), (2, 1), (3, 2)],
            [(5, 1), (3, 1), (2, 1), (1, 1)],
            [(3, 1), (5, 1), (3, 1), (2, 1)],
            [(1, 4)],
        ]
        var builder = PositionSongBuilder()
        for position in route {
            for bar in position == .f ? fPhrases : phrases {
                builder.bar(right: bar, left: [], in: position)
            }
        }
        return builder.song(title: name + " (right hand)")
    }

    /// Both hands, 8 bars per position: hands take turns, and each phrase ends with both hands together.
    /// The left hand never uses finger 2 and the right hand never uses finger 4, so F position needs no B♭.
    public var bothHands: Song {
        var builder = PositionSongBuilder()
        for position in route {
            builder.bar(right: [(1, 1), (2, 1), (3, 1), (2, 1)], left: [], in: position)
            builder.bar(right: [], left: [(5, 1), (4, 1), (3, 1), (4, 1)], in: position)
            builder.bar(right: [(1, 1), (3, 1), (5, 1), (3, 1)], left: [], in: position)
            builder.bar(right: [(1, 4)], left: [(5, 4)], in: position)
            builder.bar(right: [(3, 1), (2, 1), (1, 2)], left: [], in: position)
            builder.bar(right: [], left: [(3, 1), (4, 1), (5, 2)], in: position)
            builder.bar(right: [(5, 1), (3, 1), (2, 1), (1, 1)], left: [(1, 1), (3, 1), (4, 1), (5, 1)], in: position)
            builder.bar(right: [(1, 4)], left: [(5, 4)], in: position)
        }
        return builder.song(title: name + " (both hands)")
    }
}

/// Builds a 4/4 song bar by bar from finger numbers; finger 0 is a rest.
struct PositionSongBuilder {
    private var notes: [NoteEvent] = []
    private var barStart = 0.0
    /// Show the finger on every note (otherwise only on the first note of each bar in each hand).
    var fingerEveryNote = false

    mutating func bar(right: [(finger: Int, beats: Double)], left: [(finger: Int, beats: Double)],
                      in position: FivePosition) {
        for (hand, fingers) in [(Hand.right, right), (.left, left)] {
            var beat = barStart
            for (i, item) in fingers.enumerated() {
                defer { beat += item.beats }
                if item.finger == 0 { continue }
                notes.append(NoteEvent(id: 0, pitch: position.pitch(finger: item.finger, hand: hand),
                                       startBeat: beat, durationBeats: item.beats * 0.95,
                                       velocity: hand == .right ? 85 : 70, hand: hand,
                                       finger: i == 0 || fingerEveryNote ? item.finger : nil))
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
