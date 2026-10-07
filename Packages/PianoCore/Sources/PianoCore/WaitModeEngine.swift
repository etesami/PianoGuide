import Foundation

/// A group of notes that should be pressed together (a single note or a chord).
public struct PracticeStep: Equatable, Sendable {
    public var startBeat: Double
    public var noteIDs: [Int]
    public var pitches: Set<UInt8>
}

public enum PracticeSteps {
    /// Groups notes whose starts are within `tolerance` beats into one step.
    public static func make(from notes: [NoteEvent], hands: Set<Hand> = [.left, .right, .unknown],
                            tolerance: Double = 1.0 / 32) -> [PracticeStep] {
        var steps: [PracticeStep] = []
        for note in notes.filter({ hands.contains($0.hand) }).sorted(by: { $0.startBeat < $1.startBeat }) {
            if let last = steps.last, note.startBeat - last.startBeat <= tolerance {
                steps[steps.count - 1].noteIDs.append(note.id)
                steps[steps.count - 1].pitches.insert(note.pitch)
            } else {
                steps.append(PracticeStep(startBeat: note.startBeat, noteIDs: [note.id], pitches: [note.pitch]))
            }
        }
        return steps
    }
}

/// Wait mode: the song does not move on until every pitch of the current step has been pressed.
/// Pure logic, no timing or UI; the app feeds it note-on / note-off events.
public struct WaitModeEngine: Sendable {
    public enum Feedback: Equatable, Sendable {
        case correct(pitch: UInt8)          // part of the current step, step not complete yet
        case stepCompleted(index: Int)      // all pitches of the step pressed
        case wrong(pitch: UInt8)
        case finished                       // no more steps
    }

    /// How a key should be highlighted on screen.
    public enum KeyState: Equatable, Sendable {
        case correct    // held, and it was right when it was pressed
        case wrong      // held, and it was wrong when it was pressed
        case missed     // part of the current step, not pressed yet, after a wrong note in this step
    }

    public let steps: [PracticeStep]
    public private(set) var currentIndex = 0
    public private(set) var hitInCurrentStep: Set<UInt8> = []
    public private(set) var wrongCount = 0
    /// Held keys keep the verdict they got when pressed, even after the step moves on.
    private var heldCorrect: Set<UInt8> = []
    private var heldWrong: Set<UInt8> = []
    private var wrongInCurrentStep = false

    public init(steps: [PracticeStep]) {
        self.steps = steps
    }

    public var currentStep: PracticeStep? {
        currentIndex < steps.count ? steps[currentIndex] : nil
    }

    public var isFinished: Bool { currentIndex >= steps.count }

    public mutating func noteOn(_ pitch: UInt8) -> Feedback {
        guard let step = currentStep else { return .finished }
        guard step.pitches.contains(pitch) else {
            wrongCount += 1
            heldWrong.insert(pitch)
            wrongInCurrentStep = true
            return .wrong(pitch: pitch)
        }
        hitInCurrentStep.insert(pitch)
        heldCorrect.insert(pitch)
        if hitInCurrentStep == step.pitches {
            let completed = currentIndex
            currentIndex += 1
            hitInCurrentStep = []
            wrongInCurrentStep = false
            return .stepCompleted(index: completed)
        }
        return .correct(pitch: pitch)
    }

    /// Releasing a chord note before the whole chord is down means it must be pressed again.
    public mutating func noteOff(_ pitch: UInt8) {
        hitInCurrentStep.remove(pitch)
        heldCorrect.remove(pitch)
        heldWrong.remove(pitch)
    }

    /// Highlight for every key that should be colored; keys not in the map are drawn normally.
    public var keyStates: [UInt8: KeyState] {
        var states: [UInt8: KeyState] = [:]
        if wrongInCurrentStep, let step = currentStep {
            for pitch in step.pitches.subtracting(hitInCurrentStep) { states[pitch] = .missed }
        }
        for pitch in heldCorrect { states[pitch] = .correct }
        for pitch in heldWrong { states[pitch] = .wrong }
        return states
    }

    public mutating func reset(to index: Int = 0) {
        currentIndex = max(0, min(index, steps.count))
        hitInCurrentStep = []
        wrongCount = 0
        wrongInCurrentStep = false
    }
}
