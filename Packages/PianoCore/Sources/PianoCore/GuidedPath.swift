import Foundation

/// A guided path: lessons in order, each with a goal and steps that must be passed in order.
/// A step is one piece played in one way (listen, wait mode, timed mode, play along), with one hand or both, at a speed.
public struct GuidedPath: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let lessons: [PathLesson]

    public init(id: String, title: String, summary: String, lessons: [PathLesson]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.lessons = lessons
    }

    public var steps: [PathStep] { lessons.flatMap(\.steps) }

    /// The lesson holding `step`.
    public func lesson(of step: PathStep) -> PathLesson? {
        lessons.first { $0.steps.contains { $0.id == step.id } }
    }

    /// The step after `step` in the whole path, or nil after the last one.
    public func step(after step: PathStep) -> PathStep? {
        let all = steps
        guard let i = all.firstIndex(where: { $0.id == step.id }), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    /// The paths the app offers.
    public static let all: [GuidedPath] = [TwoHandsPath.path]
}

public struct PathLesson: Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    /// What the lesson is for, in one or two sentences.
    public let goal: String
    /// Short advice for the whole lesson.
    public let tips: [String]
    public let steps: [PathStep]
}

public struct PathStep: Identifiable, Sendable {
    public enum Mode: String, Sendable {
        /// The app plays the piece by itself (both hands); passed by listening to the end.
        case listen
        /// The piece waits for each note.
        case wait
        /// The piece moves on at the speed; only the player's notes sound.
        case timed
        /// Timed, and the app plays the other hand (needs a hand).
        case playAlong
    }

    public let id: String
    public let title: String
    /// What to do, shown while the step is open.
    public let instruction: String
    public let song: Song
    public let mode: Mode
    /// The staff the player plays: treble = right hand, bass = left hand, nil = both.
    public let hand: Clef?
    /// Share of the piece's tempo (timed, play along, listen); wait mode ignores it.
    public let speed: Double
    /// Good runs in a row needed to pass.
    public let runs: Int

    public init(id: String, title: String, instruction: String, song: Song, mode: Mode, hand: Clef? = nil,
                speed: Double = 1, runs: Int = 1) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.song = song
        self.mode = mode
        self.hand = hand
        self.speed = speed
        self.runs = runs
    }

    /// "Wait mode · both hands", "Timed 60% · left hand", "Play along 70% · you play the right hand", "Listen 75%".
    public var settingsSummary: String {
        let percent = "\(Int((speed * 100).rounded()))%"
        let hands = hand == .treble ? "right hand" : hand == .bass ? "left hand" : "both hands"
        switch mode {
        case .listen: return "Listen \(percent)"
        case .wait: return "Wait mode · \(hands)"
        case .timed: return "Timed \(percent) · \(hands)"
        case .playAlong: return "Play along \(percent) · you play the \(hands)"
        }
    }

    /// How a run went, to see whether it counts for the step.
    public struct Run: Sendable {
        public var mode: Mode
        public var hand: Clef?
        public var speed: Double
        /// Nil for listening.
        public var result: PracticeResult?
        /// The player jumped ahead of where they had played to.
        public var skippedAhead: Bool

        public init(mode: Mode, hand: Clef?, speed: Double, result: PracticeResult? = nil, skippedAhead: Bool = false) {
            self.mode = mode
            self.hand = hand
            self.speed = speed
            self.result = result
            self.skippedAhead = skippedAhead
        }
    }

    /// Whether a run was played the step's way: same mode and hand, and at least its speed (wait mode has none).
    public func matches(mode: Mode, hand: Clef?, speed: Double) -> Bool {
        guard mode == self.mode, hand == self.hand else { return false }
        return mode == .wait || speed >= self.speed - 1e-6
    }

    public enum Verdict: Equatable, Sendable {
        /// Played the step's way with few enough mistakes (the result card is green).
        case good
        /// Played the step's way, with too many mistakes.
        case tooManyMistakes
        /// Not played the step's way (other mode, hand or a slower speed, or jumped ahead): doesn't count either way.
        case notThisStep
    }

    public func verdict(_ run: Run) -> Verdict {
        guard matches(mode: run.mode, hand: run.hand, speed: run.speed), !run.skippedAhead else { return .notThisStep }
        if mode == .listen { return .good }
        guard let result = run.result else { return .notThisStep }
        return result.grade.passed ? .good : .tooManyMistakes
    }
}

/// What the player has passed in one path. Steps open in order: a step is open once every step before it is passed.
/// A good run adds one to the step's count; a run with too many mistakes starts the count again (runs are "in a row").
/// Passed steps stay passed and can be played again freely.
public struct PathProgress: Codable, Equatable, Sendable {
    /// Good runs in a row so far, per step id, for steps not yet passed.
    public private(set) var streaks: [String: Int] = [:]
    public private(set) var passed: Set<String> = []

    public init() {}

    public func isPassed(_ step: PathStep) -> Bool { passed.contains(step.id) }
    public func streak(of step: PathStep) -> Int { isPassed(step) ? step.runs : streaks[step.id] ?? 0 }

    /// The first step not yet passed, or nil when the whole path is done.
    public func current(in path: GuidedPath) -> PathStep? { path.steps.first { !isPassed($0) } }

    /// Passed, or the first one not yet passed.
    public func isOpen(_ step: PathStep, in path: GuidedPath) -> Bool {
        isPassed(step) || current(in: path)?.id == step.id
    }

    public func passedCount(in path: GuidedPath) -> Int { path.steps.filter(isPassed).count }

    public enum Outcome: Equatable, Sendable {
        /// The step is passed now (with this run).
        case passed
        /// A good run, more needed: `streak` of `runs` so far.
        case counted(streak: Int, runs: Int)
        /// Too many mistakes: the count starts again.
        case startAgain(runs: Int)
        /// The run didn't count (other settings, a step not open yet, or one already passed).
        case notCounted
    }

    /// Records a run of `step` (in `path`) and says what it did.
    @discardableResult
    public mutating func record(_ run: PathStep.Run, of step: PathStep, in path: GuidedPath) -> Outcome {
        guard !isPassed(step), isOpen(step, in: path) else { return .notCounted }
        switch step.verdict(run) {
        case .notThisStep:
            return .notCounted
        case .tooManyMistakes:
            streaks[step.id] = 0
            return .startAgain(runs: step.runs)
        case .good:
            let streak = (streaks[step.id] ?? 0) + 1
            if streak >= step.runs {
                streaks[step.id] = nil
                passed.insert(step.id)
                return .passed
            }
            streaks[step.id] = streak
            return .counted(streak: streak, runs: step.runs)
        }
    }
}
