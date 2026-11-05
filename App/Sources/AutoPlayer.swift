import AVFoundation
import PianoCore
import QuartzCore

/// Listen mode: the app plays the whole song by itself at the timed-mode speed, so the player can hear how it
/// should sound. The notes are scheduled on the audio clock by `AVAudioSequencer` (exact timing, follows the
/// song's tempo changes); a 60 Hz timer only reads the position back to move the staff.
/// The notes go to the connected piano over MIDI, or else to the sampler (see `PianoOutput`).
final class AutoPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    /// The playhead in beats while playing.
    @Published private(set) var beat = 0.0

    private let output = PianoOutput.shared
    private lazy var sequencer = AVAudioSequencer(audioEngine: output.engine)
    private var song: Song?
    private var timer: Timer?

    func play(_ song: Song, speed: Double) {
        stop()
        output.prepare()
        do {
            // The sequencer needs a running engine even when the notes go out over MIDI.
            if !output.engine.isRunning { try output.engine.start() }
            try sequencer.load(from: MIDIFileWriter.write(song, channel: PianoOutput.notesChannel), options: [])
            for track in sequencer.tracks {
                if let piano = output.destination {
                    track.destinationMIDIEndpoint = piano
                } else {
                    track.destinationAudioUnit = output.sampler
                }
            }
            sequencer.rate = Float(speed)
            sequencer.currentPositionInBeats = 0
            sequencer.prepareToPlay()
            try sequencer.start()
        } catch {
            return
        }
        self.song = song
        beat = 0
        isPlaying = true
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        guard isPlaying else { return }
        sequencer.stop()
        song?.soundingPitches(atBeat: beat).forEach(output.stopNote)
        output.stopAllNotes()
        isPlaying = false
    }

    func setSpeed(_ speed: Double) {
        sequencer.rate = Float(speed)
    }

    private func tick() {
        guard let song else { return }
        beat = sequencer.currentPositionInBeats
        // Let the last notes ring out to their full length, then stop.
        if beat >= song.durationBeats { stop() }
    }
}
