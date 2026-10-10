import Foundation

/// Hand coordination drills for a player who is fine with each hand alone but not with both together.
/// Each drill is a step harder than the one before. All are in C position (white keys only),
/// 16 bars of 4/4 at 90 BPM, with the finger number on every note. Finger 0 is a rest.
public enum HandsPractice: Int, CaseIterable, Sendable {
    /// The hands never play at the same time: whole bars, then half bars, then single beats; together only at the end.
    case turns = 1
    /// One hand holds a whole note while the other plays quarters; then the hands swap.
    case holding
    /// One hand plays half notes while the other plays quarters; then the hands swap.
    case twoAgainstOne
    /// Both hands play quarters together, each with its own shape; then the hands swap.
    case differentShapes
    /// One hand starts its notes a beat after the other, so the hands overlap; then the hands swap.
    case offTheBeat
    /// One hand plays eighths while the other plays quarters; then the hands swap.
    case eighths

    /// "Hands 1 · Taking turns", "Hands 2 · One hand holds", …
    public var name: String {
        let title: String
        switch self {
        case .turns: title = "Taking turns"
        case .holding: title = "One hand holds"
        case .twoAgainstOne: title = "Two against one"
        case .differentShapes: title = "Different shapes"
        case .offTheBeat: title = "Off the beat"
        case .eighths: title = "Eighths against quarters"
        }
        return "Hands \(rawValue) · \(title)"
    }

    private typealias Notes = [(finger: Int, beats: Double)]
    private typealias Bar = (right: Notes, left: Notes)

    /// Notes of equal length that fill a bar: 4 fingers are quarters, 8 are eighths, 1 is a whole note.
    private static func even(_ fingers: [Int]) -> Notes {
        fingers.map { ($0, 4 / Double(fingers.count)) }
    }

    /// The same notes with the hands exchanged: right finger f and left finger 6 − f play the same note name.
    private static func swapped(_ bar: Bar) -> Bar {
        func other(_ notes: Notes) -> Notes { notes.map { ($0.finger == 0 ? 0 : 6 - $0.finger, $0.beats) } }
        return (other(bar.left), other(bar.right))
    }

    /// 16 bars. Every drill but the first is an 8-bar phrase, then the same phrase with the hands swapped.
    private var bars: [Bar] {
        let even = Self.even
        let phrase: [Bar]
        switch self {
        case .turns:
            return [
                // Whole bars.
                (even([1, 2, 3, 4]), []), ([], even([5, 4, 3, 2])),
                (even([5, 4, 3, 2]), []), ([], even([1, 2, 3, 4])),
                // Half bars: the left hand echoes the right.
                (even([1, 2, 0, 0]), even([0, 0, 5, 4])), (even([3, 4, 0, 0]), even([0, 0, 3, 2])),
                (even([5, 3, 0, 0]), even([0, 0, 1, 3])), (even([1, 0]), even([0, 5])),
                // Single beats: right on 1 and 3, left on 2 and 4.
                (even([1, 0, 2, 0]), even([0, 5, 0, 4])), (even([3, 0, 4, 0]), even([0, 3, 0, 2])),
                (even([5, 0, 4, 0]), even([0, 1, 0, 2])), (even([3, 0, 2, 0]), even([0, 3, 0, 4])),
                (even([1, 0, 3, 0]), even([0, 5, 0, 3])), (even([5, 0, 3, 0]), even([0, 1, 0, 3])),
                (even([2, 0, 1, 0]), even([0, 4, 0, 5])),
                // Together at last.
                (even([1]), even([5])),
            ]
        case .holding:
            phrase = [
                (even([1, 2, 3, 4]), even([5])), (even([5, 4, 3, 2]), even([1])),
                (even([1, 3, 5, 3]), even([5])), (even([2, 3, 4, 5]), even([1])),
                (even([5, 3, 4, 2]), even([1])), (even([3, 4, 5, 3]), even([3])),
                (even([2, 4, 3, 2]), even([1])), (even([1]), even([5])),
            ]
        case .twoAgainstOne:
            phrase = [
                (even([1, 2, 3, 4]), even([5, 3])), (even([5, 4, 3, 2]), even([1, 3])),
                (even([1, 3, 5, 3]), even([5, 1])), (even([2, 3, 4, 2]), even([1, 4])),
                (even([3, 4, 5, 4]), even([3, 1])), (even([3, 2, 1, 2]), even([3, 1])),
                (even([5, 4, 3, 2]), even([1, 2])), (even([1]), even([5])),
            ]
        case .differentShapes:
            phrase = [
                (even([1, 2, 3, 1]), even([5, 3, 1, 3])), (even([5, 4, 3, 2]), even([5, 3, 1, 3])),
                (even([3, 4, 5, 3]), even([5, 1, 5, 1])), (even([2, 3, 4, 2]), even([4, 1, 4, 1])),
                (even([1, 3, 5, 3]), even([5, 3, 1, 3])), (even([4, 3, 2, 1]), even([5, 3, 1, 3])),
                (even([2, 4, 3, 2]), even([4, 1, 4, 1])), (even([1]), even([5])),
            ]
        case .offTheBeat:
            phrase = [
                // Right-hand half notes; the left hand comes in on beat 2.
                ([(1, 2), (3, 2)], [(0, 1), (5, 2), (3, 1)]), ([(5, 2), (4, 2)], [(0, 1), (1, 2), (2, 1)]),
                ([(3, 2), (2, 2)], [(0, 1), (3, 2), (4, 1)]), (even([1]), [(0, 2), (5, 2)]),
                // Right-hand quarters; the left hand still comes in on beat 2.
                (even([1, 2, 3, 4]), [(0, 1), (5, 2), (3, 1)]), (even([5, 4, 3, 2]), [(0, 1), (1, 2), (2, 1)]),
                ([(1, 1), (3, 1), (5, 2)], even([0, 5, 3, 1])), (even([1]), [(0, 2), (5, 2)]),
            ]
        case .eighths:
            phrase = [
                (even([1, 2, 3, 2, 1, 2, 3, 2]), even([5, 3, 1, 3])),
                (even([1, 2, 3, 4, 5, 4, 3, 2]), even([5, 3, 1, 3])),
                (even([5, 4, 3, 2, 1, 2, 3, 4]), even([1, 3, 5, 3])),
                (even([5, 4, 3, 4, 5, 4, 3, 4]), even([1, 4, 1, 4])),
                (even([3, 4, 5, 4, 3, 4, 5, 4]), even([3, 1, 3, 1])),
                (even([1, 3, 2, 4, 3, 5, 4, 2]), even([5, 3, 1, 3])),
                (even([2, 3, 4, 3, 2, 3, 4, 3]), even([4, 1, 4, 1])),
                (even([1]), even([5])),
            ]
        }
        return phrase + phrase.map(Self.swapped)
    }

    public var song: Song {
        var builder = PositionSongBuilder()
        builder.fingerEveryNote = true
        for bar in bars { builder.bar(right: bar.right, left: bar.left, in: .c) }
        return builder.song(title: name)
    }
}
