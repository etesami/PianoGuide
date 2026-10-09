import AVFoundation

/// Short click sounds for the timed mode's beat: a higher click on the first beat of a bar.
final class Metronome {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private lazy var accent = click(frequency: 1_760)
    private lazy var normal = click(frequency: 1_320)

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func click(accented: Bool) {
        if !engine.isRunning {
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            guard (try? engine.start()) != nil else { return }
        }
        player.scheduleBuffer(accented ? accent : normal)
        if !player.isPlaying { player.play() }
    }

    func stop() {
        player.stop()
        engine.pause()
    }

    /// A 40 ms sine "tick" that fades out quickly.
    private func click(frequency: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(format.sampleRate * 0.04)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / format.sampleRate
            samples[i] = Float(sin(2 * .pi * frequency * t) * exp(-t * 120) * 0.6)
        }
        return buffer
    }
}
