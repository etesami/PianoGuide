import CoreBluetooth
import Foundation

/// The app's own Bluetooth MIDI connection to the piano (iPad only; on the Mac the piano is paired in Audio MIDI Setup).
///
/// Apple's pairing screen (`CABTMIDICentralViewController`) only lists pianos that are advertising. A piano that is
/// already connected to the iPad (for example through the iPad's Bluetooth Settings) or to another device stops
/// advertising, so it never shows there. This class finds both kinds: it scans for nearby Bluetooth devices and also asks
/// iPadOS for MIDI devices already connected to it.
///
/// Once connected, it reads the notes itself from the Bluetooth MIDI characteristic (BLE MIDI packets) and hands them to
/// `MIDIInputService`, so it doesn't depend on iPadOS turning the connection into a CoreMIDI source. If iPadOS does that
/// too, the CoreMIDI source wins and the notes read here are ignored (see `MIDIInputService.receiveBluetooth`).
///
/// The piano is remembered (UserDefaults) and connected again by itself at launch and whenever it comes back on.
/// Bluetooth (and its permission prompt) only starts when the Bluetooth sheet is opened or a piano has been remembered.
final class BluetoothPiano: NSObject, ObservableObject {
    /// The Bluetooth LE MIDI service and its one characteristic (from the BLE MIDI specification).
    static let midiService = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
    static let midiCharacteristic = CBUUID(string: "7772E5DB-3868-4112-A1A9-F2669D106BF3")

    struct Device: Identifiable, Equatable {
        let id: UUID
        var name: String
        /// Advertises Bluetooth MIDI, or is a MIDI device already connected to the iPad.
        var isMIDI: Bool
        /// Already connected to the iPad (by Settings, another app or this one), so it doesn't advertise.
        var connectedToIPad: Bool
    }

    enum Status: Equatable {
        case idle, connecting(String), connected(String), failed(String)
    }

    /// Devices found while the sheet is open: MIDI devices first, then the other named devices nearby.
    @Published private(set) var devices: [Device] = []
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var status: Status = .idle
    /// The remembered piano's name, or nil if none.
    @Published private(set) var rememberedName: String?

    static var isSupported: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        true
        #endif
    }

    private static let idKey = "bluetoothPianoID"
    private static let nameKey = "bluetoothPianoName"

    private let midi: MIDIInputService
    private var central: CBCentralManager?
    /// Every peripheral seen; CoreBluetooth needs them kept alive to connect.
    private var peripherals: [UUID: CBPeripheral] = [:]
    /// The piano being connected or connected now.
    private var piano: CBPeripheral?
    private var wantsScan = false
    private var parser = BLEMIDIParser()

    init(midi: MIDIInputService) {
        self.midi = midi
        super.init()
        guard Self.isSupported else { return }
        rememberedName = UserDefaults.standard.string(forKey: Self.nameKey)
        if rememberedID != nil { startBluetooth() }
    }

    // MARK: - Used by the sheet

    func startScanning() {
        guard Self.isSupported else { return }
        wantsScan = true
        startBluetooth()
        scanIfReady()
    }

    func stopScanning() {
        wantsScan = false
        central?.stopScan()
    }

    func connect(_ device: Device) {
        guard let central, let peripheral = peripherals[device.id] else { return }
        if let piano, piano.identifier != peripheral.identifier { central.cancelPeripheralConnection(piano) }
        piano = peripheral
        status = .connecting(device.name)
        if peripheral.state == .connected {
            // Already connected to the iPad (Settings or another app): just start reading from it.
            didConnect(peripheral)
        } else {
            central.connect(peripheral)
        }
    }

    /// Disconnects and stops reconnecting by itself.
    func forget() {
        if let piano { central?.cancelPeripheralConnection(piano) }
        piano = nil
        UserDefaults.standard.removeObject(forKey: Self.idKey)
        UserDefaults.standard.removeObject(forKey: Self.nameKey)
        rememberedName = nil
        status = .idle
        midi.setBluetoothSource(nil)
    }

    var connectedID: UUID? {
        if case .connected = status { return piano?.identifier }
        return nil
    }

    // MARK: - Private

    private var rememberedID: UUID? {
        UserDefaults.standard.string(forKey: Self.idKey).flatMap(UUID.init(uuidString:))
    }

    private func startBluetooth() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main)
    }

    private func scanIfReady() {
        guard wantsScan, let central, central.state == .poweredOn else { return }
        // MIDI devices already connected to the iPad don't advertise: list them first.
        for peripheral in central.retrieveConnectedPeripherals(withServices: [Self.midiService]) {
            add(peripheral, name: peripheral.name, isMIDI: true)
        }
        // All devices, not only those advertising the MIDI service: some put it in the scan response only, and seeing
        // the other names helps tell what's going on (e.g. "FP-30X Audio" is the speaker connection, not MIDI).
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    private func add(_ peripheral: CBPeripheral, name: String?, isMIDI: Bool) {
        peripherals[peripheral.identifier] = peripheral
        guard let name, !name.isEmpty else { return }
        let device = Device(id: peripheral.identifier, name: name, isMIDI: isMIDI,
                            connectedToIPad: peripheral.state == .connected)
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            var merged = device
            merged.isMIDI = devices[index].isMIDI || isMIDI
            if devices[index] != merged { devices[index] = merged }
        } else {
            devices.append(device)
        }
        devices.sort { ($0.isMIDI ? 0 : 1, $0.name) < ($1.isMIDI ? 0 : 1, $1.name) }
    }

    private func reconnectRemembered() {
        guard piano == nil, let central, central.state == .poweredOn, let id = rememberedID,
              let peripheral = central.retrievePeripherals(withIdentifiers: [id]).first else { return }
        peripherals[id] = peripheral
        piano = peripheral
        if peripheral.state == .connected {
            didConnect(peripheral)
        } else {
            central.connect(peripheral)   // no time-out: completes when the piano is turned on
        }
    }

    private func didConnect(_ peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([Self.midiService])
    }

    private var pianoName: String {
        piano?.name ?? rememberedName ?? "Bluetooth piano"
    }
}

extension BluetoothPiano: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        guard central.state == .poweredOn else { return }
        scanIfReady()
        reconnectRemembered()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
            + (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? [])
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        add(peripheral, name: name, isMIDI: services.contains(Self.midiService))
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == piano?.identifier else { return }
        didConnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == piano?.identifier else { return }
        status = .failed("Couldn't connect to \(pianoName). Turn the piano off and on and try again.")
        piano = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == piano?.identifier else { return }
        midi.setBluetoothSource(nil)
        if peripheral.identifier == rememberedID {
            // Turned off or out of range: wait for it to come back.
            status = .connecting(pianoName)
            central.connect(peripheral)
        } else {
            status = .idle
            piano = nil
        }
    }
}

extension BluetoothPiano: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.midiService }) else {
            status = .failed("\(pianoName) is not a Bluetooth MIDI device. On the FP-30X, pick the one named \"… MIDI\", not \"… Audio\".")
            central?.cancelPeripheralConnection(peripheral)
            piano = nil
            return
        }
        peripheral.discoverCharacteristics([Self.midiCharacteristic], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == Self.midiCharacteristic }) else {
            status = .failed("\(pianoName) has no MIDI data channel.")
            return
        }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.isNotifying else {
            status = .failed("\(pianoName) didn't allow reading its notes\(error.map { ": " + $0.localizedDescription } ?? ".")")
            return
        }
        let name = peripheral.name ?? pianoName
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.idKey)
        UserDefaults.standard.set(name, forKey: Self.nameKey)
        rememberedName = name
        status = .connected(name)
        midi.setBluetoothSource(name)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let events = parser.parse([UInt8](data))
        if !events.isEmpty { midi.receiveBluetooth(events) }
    }
}

/// Reads note on/off from Bluetooth LE MIDI packets: a header byte, then messages, each starting with a timestamp byte
/// (both have the top bit set); a message may leave out its status byte (running status). Other messages are skipped.
struct BLEMIDIParser {
    private var status: UInt8 = 0

    mutating func parse(_ bytes: [UInt8]) -> [MIDIInputService.Event] {
        var events: [MIDIInputService.Event] = []
        guard bytes.count > 1, bytes[0] & 0x80 != 0 else { return events }
        var i = 1
        while i < bytes.count {
            if bytes[i] & 0x80 != 0 {
                // Timestamp; a status byte may follow.
                i += 1
                guard i < bytes.count else { break }
                let byte = bytes[i]
                if byte & 0x80 != 0 {
                    i += 1
                    if byte == 0xF0 {
                        // System exclusive: skip to its end (0xF7, after its own timestamp byte).
                        while i < bytes.count, bytes[i] != 0xF7 { i += 1 }
                        i += 1
                        status = 0
                        continue
                    }
                    if byte >= 0xF8 { continue }   // real-time (clock, active sensing): keeps the running status
                    status = byte
                }
            }
            let length = Self.dataLength(status)
            guard status != 0, length > 0 else {
                if status == 0 { i += 1 }   // stray data byte
                status = 0
                continue
            }
            guard i + length <= bytes.count, bytes[i..<(i + length)].allSatisfy({ $0 & 0x80 == 0 }) else { break }
            if length == 2 { events += Self.event(status: status, data1: bytes[i], data2: bytes[i + 1]) }
            i += length
        }
        return events
    }

    private static func dataLength(_ status: UInt8) -> Int {
        switch status & 0xF0 {
        case 0x80, 0x90, 0xA0, 0xB0, 0xE0: return 2
        case 0xC0, 0xD0: return 1
        default:
            switch status {
            case 0xF1, 0xF3: return 1
            case 0xF2: return 2
            default: return 0
            }
        }
    }

    private static func event(status: UInt8, data1: UInt8, data2: UInt8) -> [MIDIInputService.Event] {
        // The app's own notes, in case the piano sends them back: not the player's keys.
        let channel = status & 0x0F
        guard status < 0xF0, channel != PianoOutput.notesChannel, channel != PianoOutput.clickChannel else { return [] }
        switch status & 0xF0 {
        case 0x90 where data2 > 0: return [.noteOn(pitch: data1, velocity: data2)]
        case 0x90, 0x80: return [.noteOff(pitch: data1)]
        default: return []
        }
    }
}
