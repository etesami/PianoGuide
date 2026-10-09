import Foundation

/// Timed mode: the song moves on at a fixed speed whether or not the notes are played.
/// Each note can be hit within `window` beats either side of its start; when the playhead has passed
/// that window, every note of the step not played is counted as missed. A key that matches no note
/// in its window is a wrong note. Pure logic, no clock or UI: the app tells it where the playhead is.
public struct TimedModeEngine: Sendable {
    public enum Feedback: Equatable, Sendable {
        case hit(noteID: Int)
        case wrong(pitch: UInt8)
    }

    public let steps: [PracticeStep]
    public let window: Double
    /// The playhead, in beats (negative during the count-in).
    public private(set) var beat: Double
    /// Steps before this index have had their window pass and are judged.
    public private(set) var judgedCount = 0
    public private(set) var hitNotes: Set<Int> = []
    public private(set) var missedNotes: Set<Int> = []
    public private(set) var wrongCount = 0
    private var heldCorrect: Set<UInt8> = []
    private var heldWrong: Set<UInt8> = []

    public init(steps: [PracticeStep], window: Double = 0.5, startBeat: Double = 0) {
        self.steps = steps
        self.window = window
        self.beat = startBeat
    }

    public var isFinished: Bool { judgedCount >= steps.count }
    public var noteCount: Int { steps.reduce(0) { $0 + $1.noteIDs.count } }
    public var missedCount: Int { missedNotes.count }

    /// Moves the playhead forward and judges every step whose window has passed.
    public mutating func advance(to beat: Double) {
        self.beat = beat
        while judgedCount < steps.count, steps[judgedCount].startBeat + window < beat {
            for id in steps[judgedCount].noteIDs where !hitNotes.contains(id) { missedNotes.insert(id) }
            judgedCount += 1
        }
    }

    /// A key pressed at the current playhead: it hits the closest unplayed note of that pitch in its window.
    public mutating func noteOn(_ pitch: UInt8) -> Feedback {
        var best: (id: Int, distance: Double)?
        for step in steps[judgedCount...] {
            if step.startBeat - window > beat { break }
            let distance = abs(step.startBeat - beat)
            for (id, notePitch) in zip(step.noteIDs, step.notePitches)
            where notePitch == pitch && !hitNotes.contains(id) && distance <= window {
                if best == nil || distance < best!.distance { best = (id, distance) }
            }
        }
        guard let best else {
            wrongCount += 1
            heldCorrect.remove(pitch)
            heldWrong.insert(pitch)
            return .wrong(pitch: pitch)
        }
        hitNotes.insert(best.id)
        heldWrong.remove(pitch)
        heldCorrect.insert(pitch)
        return .hit(noteID: best.id)
    }

    public mutating func noteOff(_ pitch: UInt8) {
        heldCorrect.remove(pitch)
        heldWrong.remove(pitch)
    }

    /// Held keys keep the verdict they got when pressed.
    public var keyStates: [UInt8: WaitModeEngine.KeyState] {
        var states: [UInt8: WaitModeEngine.KeyState] = [:]
        for pitch in heldCorrect { states[pitch] = .correct }
        for pitch in heldWrong { states[pitch] = .wrong }
        return states
    }

    /// Played notes, missed notes, and the notes that can be played right now (`.next`).
    public var noteStates: [Int: WaitModeEngine.NoteState] {
        var states: [Int: WaitModeEngine.NoteState] = [:]
        for id in hitNotes { states[id] = .played }
        for id in missedNotes { states[id] = .missed }
        for step in steps[judgedCount...] {
            if step.startBeat - window > beat { break }
            for id in step.noteIDs where !hitNotes.contains(id) { states[id] = .next }
        }
        return states
    }
}

extension Song {
    /// Tempo in effect at a beat (the first tempo for beats before 0, e.g. during a count-in).
    public func bpm(atBeat beat: Double) -> Double {
        (tempoMap.last { $0.beat <= beat } ?? tempoMap[0]).bpm
    }

    /// The playhead after `seconds` of real time at `speed` (1 = the song's own tempo).
    /// Called every frame, so a tempo change inside one step is ignored.
    public func beat(after seconds: Double, from beat: Double, speed: Double) -> Double {
        beat + seconds * bpm(atBeat: beat) * speed / 60
    }
}
