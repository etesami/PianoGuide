import Foundation

/// Five-finger coordination drills in C position (white keys only), each a step harder than the one before.
/// 16 bars of 4/4 at 90 BPM; every note shows its finger number.
public enum FingerPractice: Int, CaseIterable, Sendable {
    /// Neighbouring fingers in pairs (1-2, 2-3, 3-4, 4-5): right hand, then left hand.
    case pairs = 1
    /// Skipping a finger (1-3, 2-4, 3-5): right hand, then left hand.
    case skips
    /// Hands together with the same finger numbers, so the hands move in opposite directions.
    case mirror
    /// Hands together on the same note names an octave apart, so the finger numbers differ.
    case parallel

    /// "Fingers 1 · Pairs", "Fingers 2 · Skips", …
    public var name: String {
        let title: String
        switch self {
        case .pairs: title = "Pairs"
        case .skips: title = "Skips"
        case .mirror: title = "Mirror (hands together)"
        case .parallel: title = "Parallel (hands together)"
        }
        return "Fingers \(rawValue) · \(title)"
    }

    public var song: Song {
        // Each phrase is 8 bars of right-hand finger numbers (quarter notes; a single finger is a whole note).
        let phrases: [[[Int]]]
        switch self {
        case .pairs:
            phrases = [[[1, 2, 1, 2], [2, 3, 2, 3], [3, 4, 3, 4], [4, 5, 4, 5],
                        [5, 4, 5, 4], [4, 3, 4, 3], [3, 2, 3, 2], [1]]]
        case .skips:
            phrases = [[[1, 3, 1, 3], [2, 4, 2, 4], [3, 5, 3, 5], [1, 3, 5, 3],
                        [5, 3, 5, 3], [4, 2, 4, 2], [3, 1, 3, 1], [1]]]
        case .mirror, .parallel:
            phrases = [[[1, 2, 3, 4], [5, 4, 3, 2], [1, 2, 1, 2], [3, 4, 3, 4],
                        [5, 3, 1, 3], [2, 4, 2, 4], [5, 4, 3, 2], [1]],
                       [[1, 3, 2, 4], [3, 5, 4, 2], [1, 2, 3, 2], [3, 4, 5, 4],
                        [5, 4, 3, 2], [1, 3, 5, 3], [2, 3, 4, 3], [1]]]
        }
        func notes(_ fingers: [Int]) -> [(finger: Int, beats: Double)] {
            fingers.map { ($0, 4 / Double(fingers.count)) }
        }
        var builder = PositionSongBuilder()
        builder.fingerEveryNote = true
        switch self {
        case .pairs, .skips:
            for bar in phrases[0] { builder.bar(right: notes(bar), left: [], in: .c) }
            for bar in phrases[0] { builder.bar(right: [], left: notes(bar), in: .c) }
        case .mirror:
            for bar in phrases.joined() { builder.bar(right: notes(bar), left: notes(bar), in: .c) }
        case .parallel:
            // Same key in both hands: the left hand's finger is 6 minus the right hand's (C = right 1, left 5).
            for bar in phrases.joined() {
                builder.bar(right: notes(bar), left: notes(bar.map { 6 - $0 }), in: .c)
            }
        }
        return builder.song(title: name)
    }
}
