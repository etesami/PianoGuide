import PianoCore
import SwiftUI

/// Main screen: wait mode on the chosen song (a bundled sample or an imported .mid), shown on a scrolling grand staff.
struct PracticeView: View {
    @EnvironmentObject private var midi: MIDIInputService
    @StateObject private var library = SongLibrary()
    @State private var song: Song?
    @State private var songEntry: SongLibrary.Entry?
    @State private var showLibrary = false
    /// The last song picked, as a file name ("twinkle.mid"); imported songs are looked up first.
    @AppStorage("lastSong") private var lastSong = ""
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
                staff
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
                    Button { showLibrary = true } label: { Label("Songs", systemImage: "music.note.list") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Restart") { releaseLatched(); recordAbandoned(); engine.reset() }
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
            .sheet(isPresented: $showLibrary) {
                SongLibraryView(library: library, current: songEntry, onPick: open)
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

    @ViewBuilder private var staff: some View {
        if let song {
            StaffView(song: song,
                      noteStates: engine.noteStates,
                      wrongPitches: engine.keyStates.filter { $0.value == .wrong }.map(\.key).sorted(),
                      scrollBeat: engine.currentStep?.startBeat ?? song.durationBeats)
                .animation(.easeInOut(duration: 0.3), value: engine.currentIndex)
                .frame(height: 360)
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
                    if engine.isFinished, let songEntry {
                        library.updateProgress(of: songEntry) { $0.recordCompleted(mistakes: engine.wrongCount) }
                    }
                    DispatchQueue.main.async(execute: releaseLatched)
                default: break
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { flash = .clear }
            case .noteOff(let pitch):
                engine.noteOff(pitch)
            }
        }
        guard song == nil else { return }
        let all = library.imported + library.allSamples
        guard let entry = all.first(where: { $0.url.lastPathComponent == lastSong }) ?? library.samples.first else {
            loadError = "Sample song missing from app bundle"
            return
        }
        open(entry)
    }

    /// Leaving a song before the end still counts its wrong notes towards the difficult mark.
    private func recordAbandoned() {
        guard let songEntry, !engine.isFinished else { return }
        library.updateProgress(of: songEntry) { $0.recordAbandoned(mistakes: engine.wrongCount) }
    }

    private func open(_ entry: SongLibrary.Entry) {
        do {
            let loaded = try library.load(entry)
            releaseLatched()
            recordAbandoned()
            song = loaded
            songEntry = entry
            engine = WaitModeEngine(steps: PracticeSteps.make(from: loaded.notes))
            loadError = nil
            lastSong = entry.url.lastPathComponent
        } catch {
            loadError = "Could not load \(entry.name): " + SongLibraryView.describe(error)
        }
    }
}
