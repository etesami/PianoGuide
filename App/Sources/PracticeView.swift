import PianoCore
import SwiftUI

/// First playable screen: wait mode on the bundled sample song.
/// Upcoming steps are shown as text for now; falling notes come in milestone 3.
struct PracticeView: View {
    @EnvironmentObject private var midi: MIDIInputService
    @State private var song: Song?
    @State private var engine = WaitModeEngine(steps: [])
    @State private var loadError: String?
    @State private var showPairing = false
    @State private var flash: Color = .clear
    /// On-screen chord keys stay held after the click/touch ends until the chord is complete,
    /// so chords can be played with a mouse (simulator, Mac). The real piano is unaffected.
    @State private var latched: Set<UInt8> = []
    @AppStorage("showKeyLabels") private var showKeyLabels = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                upcomingSteps
                Spacer()
                KeyboardView(range: keyboardRange,
                             states: engine.keyStates,
                             pressed: midi.pressed,
                             showLabels: showKeyLabels,
                             onPress: { midi.simulate(.noteOn(pitch: $0, velocity: 100)) },
                             onRelease: releaseOnScreenKey)
                    .frame(height: 180)
            }
            .padding()
            .background(flash.opacity(0.15).animation(.easeOut(duration: 0.3), value: flash))
            .navigationTitle(song?.title ?? "PianoGuide")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Restart") { releaseLatched(); engine.reset() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showKeyLabels.toggle() } label: {
                        Label(showKeyLabels ? "Hide Key Labels" : "Show Key Labels",
                              systemImage: showKeyLabels ? "textformat" : "textformat.slash")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPairing = true } label: { Label("Bluetooth MIDI", systemImage: "dot.radiowaves.left.and.right") }
                }
            }
            .sheet(isPresented: $showPairing, onDismiss: midi.connectAllSources) {
                BluetoothMIDIPairingView()
            }
        }
        .onAppear(perform: load)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(midi.sourceNames.isEmpty ? "No MIDI keyboard connected. Tap the Bluetooth button, or use the keys below."
                                          : "Connected: " + midi.sourceNames.joined(separator: ", "))
                .font(.subheadline).foregroundColor(.secondary)
            if let loadError = loadError { Text(loadError).foregroundColor(.red) }
            Text(engine.isFinished && !engine.steps.isEmpty
                 ? "Finished! Wrong notes: \(engine.wrongCount)"
                 : "Step \(engine.currentIndex + 1) of \(engine.steps.count) · wrong notes: \(engine.wrongCount)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var upcomingSteps: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Array(engine.steps.enumerated()), id: \.offset) { index, step in
                    Text(step.pitches.sorted().map { NoteName.of($0) }.joined(separator: "+"))
                        .font(.system(.title3, design: .monospaced))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(
                            index == engine.currentIndex ? Color.blue.opacity(0.3)
                            : index < engine.currentIndex ? Color.green.opacity(0.2) : Color.gray.opacity(0.1)))
                }
            }
        }
    }

    private var keyboardRange: ClosedRange<UInt8> {
        guard let range = song?.pitchRange else { return 48...84 }
        // Pad to whole octaves starting at C so the keyboard looks normal.
        let lo = UInt8(max(21, Int(range.lowerBound) / 12 * 12))
        let hi = UInt8(min(108, (Int(range.upperBound) / 12 + 1) * 12))
        return lo...hi
    }

    private func releaseOnScreenKey(_ pitch: UInt8) {
        if let chord = engine.currentStep?.pitches, chord.count > 1, chord.contains(pitch) {
            latched.insert(pitch)
        } else {
            midi.simulate(.noteOff(pitch: pitch))
        }
    }

    private func releaseLatched() {
        let pitches = latched
        latched = []
        pitches.forEach { midi.simulate(.noteOff(pitch: $0)) }
    }

    private func load() {
        midi.onEvent = { event in
            switch event {
            case .noteOn(let pitch, _):
                switch engine.noteOn(pitch) {
                case .wrong: flash = .red
                case .stepCompleted:
                    flash = .green
                    DispatchQueue.main.async(execute: releaseLatched)
                default: break
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { flash = .clear }
            case .noteOff(let pitch):
                engine.noteOff(pitch)
            }
        }
        guard song == nil else { return }
        do {
            guard let url = Bundle.main.url(forResource: "twinkle", withExtension: "mid", subdirectory: "SampleSongs") else {
                loadError = "Sample song missing from app bundle"
                return
            }
            let loaded = try MIDIFileParser.parse(Data(contentsOf: url), title: "Twinkle Twinkle")
            song = loaded
            engine = WaitModeEngine(steps: PracticeSteps.make(from: loaded.notes))
        } catch {
            loadError = "Could not load song: \(error)"
        }
    }
}
