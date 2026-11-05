import PianoCore
import QuartzCore
import SwiftUI

/// Timed mode for one song: a clock moves the playhead at the chosen speed (with a one-bar count-in),
/// the metronome clicks every beat, and the engine judges the notes as the playhead passes them.
/// After the staff is dragged to a new place (`seek`), the next Play first clicks one bar while the music waits.
/// With a clef chosen, only that staff is judged; play-along (`accompanied`) also has the app play the other staff.
final class TimedSession: ObservableObject {
    @Published private(set) var engine = TimedModeEngine(steps: [])
    @Published private(set) var isPlaying = false
    /// The app plays the other staff in this run.
    @Published private(set) var accompanied = false
    /// The clicks go on after the count-in. The count-in always clicks, to show when to start.
    var metronomeOn = true
    /// Called once when the playhead has passed the last note.
    var onFinished: (() -> Void)?

    private var song: Song?
    private var speed = 1.0
    private var timer: Timer?
    private var lastTick: CFTimeInterval = 0
    private let output = PianoOutput.shared
    /// The staff the player plays (nil = both).
    private var clef: Clef?
    private var accompaniment: Accompaniment?
    /// Set by `seek`: the next Play starts with a one-bar count-in.
    private var countInPending = false
    /// During that count-in, a playhead that runs up to `engine.beat` (the music doesn't move).
    private var countInBeat: Double?

    private var beatsPerBar: Double { max(1, song?.initialTimeSignature.beatsPerBar ?? 4) }
    var hasStarted: Bool { engine.beat > -beatsPerBar }

    /// The whole song has gone by: the player's notes and, in play-along, the app's.
    var isFinished: Bool { engine.isFinished && (!accompanied || accompaniment?.isFinished ?? true) }

    func load(_ song: Song, speed: Double) {
        self.song = song
        self.speed = speed
        setClef(nil)
    }

    /// Chooses the staff the player plays and starts again from the beginning.
    func setClef(_ clef: Clef?) {
        self.clef = clef
        restart()
    }

    func restart() {
        guard let song else { return }
        pause()
        accompanied = false
        countInPending = false
        engine = TimedModeEngine(steps: PracticeSteps.make(from: song.notes, clef: clef), startBeat: -beatsPerBar)
        accompaniment = clef.map { Accompaniment(song: song, playerClef: $0) }
        updateWindows()
    }

    func setSpeed(_ speed: Double) {
        self.speed = speed
        updateWindows()
    }

    /// Hit window: ½ beat early to ¾ beat late, but at fast speeds never shorter than
    /// 0.25 s early / 0.4 s late, so small timing slips (and MIDI/audio delay) don't count as misses.
    private func updateWindows() {
        guard let song else { return }
        let beatsPerSecond = song.bpm(atBeat: 0) * speed / 60
        engine.early = max(0.5, 0.25 * beatsPerSecond)
        engine.late = max(0.75, 0.4 * beatsPerSecond)
    }

    /// Moves the music to `beat` (dragging the staff); playing goes on from there after a count-in if `resume`.
    func seek(to beat: Double, resume: Bool) {
        pause()
        engine.seek(to: beat)
        countInPending = true
        if resume { play(accompanied: accompanied) }
    }

    /// `accompanied`: the app plays the other staff (needs a clef chosen).
    func play(accompanied: Bool = false) {
        guard song != nil, !engine.steps.isEmpty else { return }
        pause()
        if isFinished { restart() }
        self.accompanied = accompanied && accompaniment != nil
        if self.accompanied { accompaniment?.seek(to: max(0, engine.beat)).forEach(output.stopNote) }
        output.prepare()
        isPlaying = true
        lastTick = CACurrentMediaTime()
        if countInPending {
            countInPending = false
            countInBeat = engine.beat - beatsPerBar
            if let start = countInBeat, start == floor(start) { output.click(accented: isBarStart(start)) }
        } else if !hasStarted {
            output.click(accented: true)   // first click of the count-in
        }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
        output.stopClicks()
        accompaniment?.silence().forEach(output.stopNote)
        if countInBeat != nil {
            countInBeat = nil
            countInPending = true
        }
    }

    func noteOn(_ pitch: UInt8) -> TimedModeEngine.Feedback { engine.noteOn(pitch) }
    func noteOff(_ pitch: UInt8) { engine.noteOff(pitch) }

    private func tick() {
        guard let song else { return }
        let now = CACurrentMediaTime()
        let old = countInBeat ?? engine.beat
        let new = song.beat(after: now - lastTick, from: old, speed: speed)
        lastTick = now
        // A click on every whole beat crossed; bars count from beat 0, so the count-in's first beat is accented too.
        let countingIn = new < 0 || (countInBeat != nil && new < engine.beat)
        if floor(new) > floor(old), metronomeOn || countingIn { output.click(accented: isBarStart(floor(new))) }
        if countInBeat != nil {
            if new < engine.beat { countInBeat = new; return }
            countInBeat = nil
        }
        engine.advance(to: new)
        if accompanied, let events = accompaniment?.advance(to: new) {
            events.stops.forEach(output.stopNote)
            events.starts.forEach { output.startNote($0.pitch, velocity: $0.velocity) }
        }
        if isFinished {
            pause()
            onFinished?()
        }
    }

    private func isBarStart(_ beat: Double) -> Bool {
        (beat.truncatingRemainder(dividingBy: beatsPerBar) + beatsPerBar).truncatingRemainder(dividingBy: beatsPerBar) == 0
    }
}
