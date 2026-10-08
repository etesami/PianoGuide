/// What the user has done with one song: how often it was played to the end, and how many wrong notes it
/// recently took. Saved by the app per song; drives the "completed" and "difficult" marks in the song list.
public struct SongProgress: Codable, Equatable, Sendable {
    /// A song is marked difficult when `mistakes` reaches this.
    public static let difficultMistakes = 5

    public private(set) var timesCompleted = 0
    /// Wrong notes in the latest finished run, raised by any later unfinished attempt with more.
    /// So the difficult mark only goes away by finishing the song with fewer mistakes. Nil if never played.
    public private(set) var mistakes: Int?

    public init() {}

    public var isCompleted: Bool { timesCompleted > 0 }
    public var isDifficult: Bool { (mistakes ?? 0) >= Self.difficultMistakes }

    /// The song was played to the end with `mistakes` wrong notes.
    public mutating func recordCompleted(mistakes: Int) {
        timesCompleted += 1
        self.mistakes = mistakes
    }

    /// The song was left (restart or another song picked) before the end, after `mistakes` wrong notes.
    public mutating func recordAbandoned(mistakes: Int) {
        guard mistakes > 0 else { return }
        self.mistakes = max(self.mistakes ?? 0, mistakes)
    }
}
