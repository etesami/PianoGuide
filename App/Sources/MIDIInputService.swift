import CoreMIDI
import Foundation

/// Listens to every connected MIDI source (Bluetooth, USB, network) and publishes note events.
/// Bluetooth devices show up here once paired via `BluetoothMIDIPairingView`.
final class MIDIInputService: ObservableObject {
    enum Event {
        case noteOn(pitch: UInt8, velocity: UInt8)
        case noteOff(pitch: UInt8)
    }

    @Published private(set) var sourceNames: [String] = []
    @Published private(set) var pressed: Set<UInt8> = []
    @Published private(set) var lastError: String?

    /// Called on the main thread for each note event (from hardware or the on-screen keyboard).
    var onEvent: ((Event) -> Void)?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()

    init() {
        let status = MIDIClientCreateWithBlock("PianoGuide" as CFString, &client) { [weak self] notification in
            if notification.pointee.messageID == .msgSetupChanged {
                DispatchQueue.main.async { self?.connectAllSources() }
            }
        }
        guard status == noErr else {
            lastError = "MIDI client error \(status)"
            return
        }
        MIDIInputPortCreateWithProtocol(client, "Input" as CFString, ._1_0, &inputPort) { [weak self] eventList, _ in
            self?.handle(eventList)
        }
        connectAllSources()
    }

    func connectAllSources() {
        var names: [String] = []
        for i in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(inputPort, source, nil)   // reconnecting an existing source is harmless
            names.append(Self.name(of: source))
        }
        sourceNames = names
    }

    /// Lets the on-screen keyboard behave exactly like a real one.
    func simulate(_ event: Event) {
        deliver(event)
    }

    private func handle(_ eventList: UnsafePointer<MIDIEventList>) {
        var events: [Event] = []
        let wordsOffset = MemoryLayout<MIDIEventPacket>.offset(of: \MIDIEventPacket.words)!
        for packet in eventList.unsafeSequence() {
            let words = UnsafeRawPointer(packet).advanced(by: wordsOffset).assumingMemoryBound(to: UInt32.self)
            for i in 0..<Int(packet.pointee.wordCount) {
                let word = words[i]
                // Universal MIDI Packet, type 2 = MIDI 1.0 channel voice message (1 word).
                guard word >> 28 == 0x2 else { continue }
                let status = UInt8((word >> 16) & 0xF0)
                let pitch = UInt8((word >> 8) & 0x7F)
                let velocity = UInt8(word & 0x7F)
                switch status {
                case 0x90 where velocity > 0: events.append(.noteOn(pitch: pitch, velocity: velocity))
                case 0x90, 0x80: events.append(.noteOff(pitch: pitch))
                default: break
                }
            }
        }
        guard !events.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in events.forEach { self?.deliver($0) } }
    }

    private func deliver(_ event: Event) {
        switch event {
        case .noteOn(let pitch, _): pressed.insert(pitch)
        case .noteOff(let pitch): pressed.remove(pitch)
        }
        onEvent?(event)
    }

    private static func name(of endpoint: MIDIEndpointRef) -> String {
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
        return (name?.takeRetainedValue() as String?) ?? "Unknown source"
    }
}
