import CoreAudioKit
import CoreBluetooth
import SwiftUI

/// The Bluetooth sheet. On the iPad: the app's own list of nearby Bluetooth devices (`BluetoothPiano`), MIDI devices
/// first; tapping one connects it. Apple's pairing screen stays available as a second way. On the Mac, Apple's screen only
/// (the piano is normally paired in Audio MIDI Setup there).
struct BluetoothMIDIPairingView: View {
    @EnvironmentObject private var midi: MIDIInputService
    @ObservedObject var bluetooth: BluetoothPiano
    @Environment(\.dismiss) private var dismiss
    @State private var showApple = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(midi.connectedNames.isEmpty ? "No keyboard connected yet."
                                                     : "Connected: " + midi.connectedNames.joined(separator: ", "))
                        .fontWeight(.semibold)
                        .foregroundStyle(midi.connectedNames.isEmpty ? Color.secondary : Color.green)
                    statusLine
                }
                if BluetoothPiano.isSupported {
                    if let problem = bluetoothProblem {
                        Section { Text(problem).foregroundStyle(.red) }
                    } else {
                        deviceSections
                    }
                    if let name = bluetooth.rememberedName {
                        Section {
                            HStack {
                                Text("Reconnects by itself: \(name)")
                                Spacer()
                                Button("Forget", role: .destructive) { bluetooth.forget() }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("On the Mac, pair the piano in Audio MIDI Setup → Window → Show MIDI Studio → Bluetooth.")
                    }
                }
                Section {
                    Button("Open Apple's Bluetooth MIDI screen") { showApple = true }
                } footer: {
                    Text("Another way to connect, if the piano isn't in the list above.")
                }
            }
            .navigationTitle("Bluetooth MIDI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .onAppear { bluetooth.startScanning() }
        .onDisappear { bluetooth.stopScanning() }
        .sheet(isPresented: $showApple, onDismiss: midi.connectAllSources) {
            AppleBluetoothMIDIScreen(onDone: { showApple = false })
        }
    }

    @ViewBuilder private var deviceSections: some View {
        let pianos = bluetooth.devices.filter(\.isMIDI)
        let others = bluetooth.devices.filter { !$0.isMIDI }
        Section {
            if pianos.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Searching for Bluetooth MIDI pianos…").foregroundStyle(.secondary)
                }
            }
            ForEach(pianos) { row($0) }
        } header: {
            Text("MIDI devices")
        } footer: {
            Text("Turn on the piano's Bluetooth (no pairing mode needed for MIDI) and keep it near the iPad. "
                 + "The FP-30X shows as \"FP-30X MIDI\". Don't pair it in the iPad's Settings.")
        }
        if !others.isEmpty {
            Section {
                ForEach(others) { row($0) }
            } header: {
                Text("Other Bluetooth devices nearby")
            } footer: {
                Text("These don't say they are MIDI devices. \"… Audio\" is the piano's speaker connection, not MIDI. "
                     + "Tapping one tries it anyway.")
            }
        }
    }

    private func row(_ device: BluetoothPiano.Device) -> some View {
        Button { bluetooth.connect(device) } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.name).foregroundStyle(.primary)
                    if device.connectedToIPad, bluetooth.connectedID != device.id {
                        Text("Connected to the iPad").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if bluetooth.connectedID == device.id {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if case .connecting(let name) = bluetooth.status, name == device.name {
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch bluetooth.status {
        case .idle: EmptyView()
        case .connecting(let name): Text("Connecting to \(name)…").foregroundStyle(.secondary)
        case .connected(let name): Text("\(name) is connected over Bluetooth.").foregroundStyle(.secondary)
        case .failed(let message): Text(message).foregroundStyle(.red)
        }
    }

    private var bluetoothProblem: String? {
        let denied = "PianoGuide may not use Bluetooth. Turn it on in the iPad's Settings → Privacy & Security → Bluetooth → PianoGuide."
        if CBManager.authorization == .denied || CBManager.authorization == .restricted { return denied }
        switch bluetooth.bluetoothState {
        case .poweredOff: return "Bluetooth is off. Turn it on in Control Center or Settings."
        case .unsupported: return "This device has no Bluetooth LE."
        case .unauthorized: return denied
        default: return nil
        }
    }
}

/// Apple's `CABTMIDICentralViewController` in its own navigation controller (tapping a device pushes a screen there),
/// with a Done button.
private struct AppleBluetoothMIDIScreen: UIViewControllerRepresentable {
    var onDone: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let central = CABTMIDICentralViewController()
        central.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { _ in onDone() })
        return UINavigationController(rootViewController: central)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}
