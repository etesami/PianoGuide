import PianoCore
import QuartzCore
import SwiftUI

/// Timed mode for one song: a clock moves the playhead at the chosen speed (with a one-bar count-in),
/// the metronome clicks every beat, and the engine judges the notes as the playhead passes them.
final class TimedSession: ObservableObject {
    @Published private(set) var engine = TimedModeEngine(steps: [])
    @Published private(set) var isPlaying = false
    /// Called once when the playhead has passed the last note.
    var onFinished: (() -> Void)?

    private var song: Song?
    private var speed = 1.0
    private var timer: Timer?
    private var lastTick: CFTimeInterval = 0
    private let metronome = Metronome()

    private var beatsPerBar: Double { max(1, song?.initialTimeSignature.beatsPerBar ?? 4) }
    var hasStarted: Bool { engine.beat > -beatsPerBar }

    func load(_ song: Song, speed: Double) {
        pause()
        self.song = song
        self.speed = speed
        engine = TimedModeEngine(steps: PracticeSteps.make(from: song.notes), startBeat: -beatsPerBar)
        updateWindows()
    }

    func restart() {
        guard let song else { return }
        load(song, speed: speed)
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

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        guard song != nil else { return }
        if engine.isFinished { restart() }
        isPlaying = true
        lastTick = CACurrentMediaTime()
        if !hasStarted { metronome.click(accented: true) }   // first click of the count-in
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
        metronome.stop()
    }

    func noteOn(_ pitch: UInt8) -> TimedModeEngine.Feedback { engine.noteOn(pitch) }
    func noteOff(_ pitch: UInt8) { engine.noteOff(pitch) }

    private func tick() {
        guard let song else { return }
        let now = CACurrentMediaTime()
        let old = engine.beat
        let new = song.beat(after: now - lastTick, from: old, speed: speed)
        lastTick = now
        // A click on every whole beat crossed; bars count from beat 0, so the count-in's first beat is accented too.
        if floor(new) > floor(old) {
            let whole = floor(new)
            let inBar = (whole.truncatingRemainder(dividingBy: beatsPerBar) + beatsPerBar)
                .truncatingRemainder(dividingBy: beatsPerBar)
            metronome.click(accented: inBar == 0)
        }
        engine.advance(to: new)
        if engine.isFinished {
            pause()
            onFinished?()
        }
    }
}
