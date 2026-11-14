import SwiftUI

@main
struct PianoGuideApp: App {
    @StateObject private var midi: MIDIInputService
    /// Started at launch, so a piano connected before reconnects without opening the Bluetooth sheet.
    @StateObject private var bluetooth: BluetoothPiano

    init() {
        let midi = MIDIInputService()
        _midi = StateObject(wrappedValue: midi)
        _bluetooth = StateObject(wrappedValue: BluetoothPiano(midi: midi))
    }

    var body: some Scene {
        WindowGroup {
            PracticeView()
                .environmentObject(midi)
                .environmentObject(bluetooth)
        }
    }
}
