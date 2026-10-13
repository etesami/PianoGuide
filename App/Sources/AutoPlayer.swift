import AVFoundation
import PianoCore
import QuartzCore

/// Listen mode: the app plays the whole song by itself at the timed-mode speed, so the player can hear how it
/// should sound. The notes are scheduled on the audio clock by `AVAudioSequencer` (exact timing, follows the
/// song's tempo changes); a 60 Hz timer only reads the position back to move the staff.
final class AutoPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    /// The playhead in beats while playing.
    @Published private(set) var beat = 0.0

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private lazy var sequencer = AVAudioSequencer(audioEngine: engine)
    private var song: Song?
    private var timer: Timer?

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        // macOS (Catalyst) ships a General MIDI sound bank with a piano; iPadOS doesn't, so there the sampler
        // keeps its built-in plain tone.
        let bank = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
        if FileManager.default.fileExists(atPath: bank.path) {
            try? sampler.loadSoundBankInstrument(at: bank, program: 0,
                                                 bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                                 bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        }
    }

    func play(_ song: Song, speed: Double) {
        stop()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        do {
            if !engine.isRunning { try engine.start() }
            try sequencer.load(from: MIDIFileWriter.write(song), options: [])
            for track in sequencer.tracks { track.destinationAudioUnit = sampler }
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
        for pitch in UInt8(0)...127 { sampler.stopNote(pitch, onChannel: 0) }
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
