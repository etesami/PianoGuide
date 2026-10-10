/// A mark the user puts on a song by hand, to find it again later.
public enum SongMark: String, Codable, CaseIterable, Sendable {
    /// Harder than it looks; practise it again.
    case hard
    /// Worth coming back to.
    case interesting
}

/// What the user has done with one song: how often it was played to the end, how many wrong notes it
/// recently took, and the user's own mark. Saved by the app per song; drives the "completed", "difficult"
/// and hard / interesting marks in the song list.
public struct SongProgress: Codable, Equatable, Sendable {
    /// A run with more mistakes than this share of the song's notes needs more practice (marks the song difficult).
    public static let mistakeRatio = 0.1
    /// The limit for progress saved before the note count was stored: this many mistakes or more.
    public static let difficultMistakes = 5

    /// Whether `mistakes` in a song of `notes` notes is too many (nil `notes`: the old fixed limit).
    public static func isTooMany(mistakes: Int, notes: Int?) -> Bool {
        guard let notes else { return mistakes >= difficultMistakes }
        return Double(mistakes) > Double(notes) * mistakeRatio
    }

    public private(set) var timesCompleted = 0
    /// Wrong notes in the latest finished run, raised by any later unfinished attempt with more.
    /// So the difficult mark only goes away by finishing the song with fewer mistakes. Nil if never played.
    public private(set) var mistakes: Int?
    /// Notes in the song when `mistakes` was recorded. (Missing in data saved before it was stored.)
    public private(set) var notes: Int?
    /// Set by the user, not by playing. Nil if unmarked. (Missing in data saved before marks existed.)
    public var mark: SongMark?

    public init() {}

    public var isCompleted: Bool { timesCompleted > 0 }
    public var isDifficult: Bool { Self.isTooMany(mistakes: mistakes ?? 0, notes: notes) }

    /// The song (`notes` notes) was played to the end with `mistakes` wrong notes.
    public mutating func recordCompleted(mistakes: Int, notes: Int) {
        timesCompleted += 1
        self.mistakes = mistakes
        self.notes = notes
    }

    /// The song was left (restart or another song picked) before the end, after `mistakes` wrong notes.
    public mutating func recordAbandoned(mistakes: Int, notes: Int) {
        guard mistakes > 0 else { return }
        self.mistakes = max(self.mistakes ?? 0, mistakes)
        self.notes = notes
    }
}
