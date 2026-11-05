import AVFoundation
import CoreMIDI

/// Where the app's own sound goes. With a piano connected, notes and clicks go to it over MIDI, so the piano makes the
/// sound itself; otherwise the notes go to a sampler and the clicks to `Metronome`, through the device's audio output.
///
/// The app's notes use their own channel, so `volume` (Control Change 7) leaves the player's own keys alone.
/// On the FP-30X, channels other than 4 play GM2 sounds, so the notes channel is set to GM2's grand piano.
final class PianoOutput {
    static let shared = PianoOutput()

    /// MIDI channels, 0-based: 1 is "channel 2", 9 is "channel 10" (drums).
    static let notesChannel: UInt8 = 1
    static let clickChannel: UInt8 = 9

    /// How loud the app's sound is, 0…1.
    var volume: Float = 0.5 {
        didSet { applyVolume() }
    }

    /// The connected piano, if any.
    private(set) var destination: MIDIEndpointRef?

    let engine = AVAudioEngine()
    let sampler = AVAudioUnitSampler()
    private let metronome = Metronome()
    private var client = MIDIClientRef()
    private var outputPort = MIDIPortRef()

    private init() {
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
        let status = MIDIClientCreateWithBlock("PianoGuide Output" as CFString, &client) { [weak self] notification in
            if notification.pointee.messageID == .msgSetupChanged {
                DispatchQueue.main.async { self?.findDestination() }
            }
        }
        guard status == noErr else { return }
        MIDIOutputPortCreate(client, "Output" as CFString, &outputPort)
        findDestination()
    }

    /// Call before playing: sets up the piano's sounds (it may have been turned off since) or starts the sampler.
    func prepare() {
        if destination != nil {
            // Bank select + program: GM2 grand piano, GM2 standard drum kit.
            send(0xB0, Self.notesChannel, 0, 121)
            send(0xB0, Self.notesChannel, 32, 0)
            send(0xC0, Self.notesChannel, 0, 0)
            send(0xB0, Self.clickChannel, 0, 120)
            send(0xB0, Self.clickChannel, 32, 0)
            send(0xC0, Self.clickChannel, 0, 0)
        }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        if !engine.isRunning { try? engine.start() }
        applyVolume()
    }

    func startNote(_ pitch: UInt8, velocity: UInt8) {
        if destination != nil {
            send(0x90, Self.notesChannel, pitch, velocity)
        } else {
            sampler.startNote(pitch, withVelocity: velocity, onChannel: Self.notesChannel)
        }
    }

    func stopNote(_ pitch: UInt8) {
        if destination != nil {
            send(0x80, Self.notesChannel, pitch, 0)
        } else {
            sampler.stopNote(pitch, onChannel: Self.notesChannel)
        }
    }

    /// Stops anything the app left sounding.
    func stopAllNotes() {
        if destination != nil {
            send(0xB0, Self.notesChannel, 123, 0)   // All Notes Off
        }
        for pitch in UInt8(0)...127 { sampler.stopNote(pitch, onChannel: Self.notesChannel) }
    }

    func click(accented: Bool) {
        if destination != nil {
            // High and low wood block in the General MIDI drum map; a short note, so the off can follow at once.
            let pitch: UInt8 = accented ? 76 : 77
            send(0x90, Self.clickChannel, pitch, 100)
            send(0x80, Self.clickChannel, pitch, 0)
        } else {
            metronome.click(accented: accented)
        }
    }

    func stopClicks() {
        metronome.stop()
    }

    private func applyVolume() {
        engine.mainMixerNode.outputVolume = volume
        metronome.volume = volume
        guard destination != nil else { return }
        let value = UInt8((max(0, min(1, volume)) * 127).rounded())
        send(0xB0, Self.notesChannel, 7, value)
        send(0xB0, Self.clickChannel, 7, value)
    }

    /// The first real device. The always-present "Network Session" and Mac "IAC Driver" ports are not pianos.
    private func findDestination() {
        destination = (0..<MIDIGetNumberOfDestinations()).lazy.map { MIDIGetDestination($0) }.first { endpoint in
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
            let text = (name?.takeRetainedValue() as String?) ?? ""
            return !text.hasPrefix("Network") && !text.hasPrefix("IAC")
        }
        if destination != nil { prepare() }
    }

    /// Sends one MIDI 1.0 channel message.
    private func send(_ status: UInt8, _ channel: UInt8, _ data1: UInt8, _ data2: UInt8) {
        guard let destination else { return }
        // Universal MIDI Packet, type 2 = MIDI 1.0 channel voice message (1 word).
        var word = UInt32(0x2) << 28 | UInt32(status | channel) << 16 | UInt32(data1) << 8 | UInt32(data2)
        var list = MIDIEventList()
        let packet = MIDIEventListInit(&list, ._1_0)
        _ = MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, 0, 1, &word)
        MIDISendEventList(outputPort, destination, &list)
    }
}
