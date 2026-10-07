import SwiftUI

@main
struct PianoGuideApp: App {
    @StateObject private var midi = MIDIInputService()

    var body: some Scene {
        WindowGroup {
            PracticeView()
                .environmentObject(midi)
        }
    }
}
