/// How a song played to the end went, shown to the user when it finishes.
/// Mistakes are wrong notes (wait mode) or missed + wrong notes (timed mode), the same count the progress uses,
/// and the same limit (more than `SongProgress.mistakeRatio` of the notes), so a "needs practice" result
/// is exactly a run that gives the song the difficult mark.
public struct PracticeResult: Equatable, Sendable {
    public enum Grade: Equatable, Sendable {
        /// No mistakes.
        case perfect
        /// A few mistakes, below the difficult mark: counts as passed.
        case almost
        /// Enough mistakes to mark the song difficult.
        case needsPractice

        public var passed: Bool { self != .needsPractice }
    }

    public var timed: Bool
    /// Notes in the song (a chord counts each of its notes).
    public var total: Int
    public var wrong: Int
    /// Notes not played in time (timed mode only; always 0 in wait mode).
    public var missed: Int

    public init(timed: Bool, total: Int, wrong: Int, missed: Int = 0) {
        self.timed = timed
        self.total = total
        self.wrong = wrong
        self.missed = missed
    }

    public var mistakes: Int { wrong + missed }

    public var grade: Grade {
        mistakes == 0 ? .perfect
            : SongProgress.isTooMany(mistakes: mistakes, notes: total) ? .needsPractice : .almost
    }

    /// Notes played in time (timed mode); in wait mode every step is played in the end, so this is `total`.
    public var played: Int { total - missed }
}
