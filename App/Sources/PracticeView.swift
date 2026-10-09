import PianoCore
import SwiftUI

/// Main screen: the chosen song (a bundled sample or an imported .mid) on a scrolling grand staff, in wait mode
/// (the song waits for each note) or timed mode (it moves on at the chosen speed with a metronome; misses are counted).
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
    @AppStorage("timedMode") private var timedMode = false
    /// Timed mode's speed as a fraction of the song's own tempo.
    @AppStorage("timedSpeed") private var speed = 0.75
    @StateObject private var timed = TimedSession()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                staff
                Spacer()
                KeyboardView(range: keyboardRange,
                             states: timedMode ? timed.engine.keyStates : engine.keyStates,
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
                    Button { timed.pause(); showLibrary = true } label: { Label("Songs", systemImage: "music.note.list") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Restart") { releaseLatched(); recordAbandoned(); engine.reset(); timed.restart() }
                }
                ToolbarItem(placement: .principal) {
                    Picker("Mode", selection: $timedMode) {
                        Text("Wait").tag(false)
                        Text("Timed").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let songEntry {
                        let mark = library.progress(of: songEntry).mark
                        Menu {
                            SongMarkPicker(mark: Binding(get: { mark }, set: { library.setMark($0, of: songEntry) }))
                        } label: {
                            Label(mark?.title ?? "Mark Song", systemImage: mark?.systemImage ?? "flag")
                        }
                        .tint(mark?.color)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showKeyLabels.toggle() } label: {
                        Label(showKeyLabels ? "Hide Key Labels" : "Show Key Labels",
                              systemImage: showKeyLabels ? "textformat" : "textformat.slash")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { timed.pause(); showPairing = true } label: { Label("Bluetooth MIDI", systemImage: "dot.radiowaves.left.and.right") }
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
        .onChange(of: timedMode) { wasTimed, _ in
            releaseLatched()
            recordAbandoned(timed: wasTimed)
            engine.reset()
            timed.restart()
        }
        .onChange(of: speed) { _, new in timed.setSpeed(new) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(midi.sourceNames.isEmpty ? "No MIDI keyboard connected. Tap the Bluetooth button, or use the keys below."
                                          : "Connected: " + midi.sourceNames.joined(separator: ", "))
                .font(.subheadline).foregroundColor(.secondary)
            if let loadError = loadError { Text(loadError).foregroundColor(.red) }
            if timedMode {
                timedControls
            } else {
                Text(engine.isFinished && !engine.steps.isEmpty
                     ? "Finished! Wrong notes: \(engine.wrongCount)"
                     : "Step \(engine.currentIndex + 1) of \(engine.steps.count) · wrong notes: \(engine.wrongCount)")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timedControls: some View {
        let e = timed.engine
        let percent = Int((speed * 100).rounded())
        let bpm = Int(((song?.bpm(atBeat: max(0, e.beat)) ?? 120) * speed).rounded())
        return HStack(spacing: 20) {
            Button { timed.togglePlay() } label: {
                Label(timed.isPlaying ? "Pause" : "Play", systemImage: timed.isPlaying ? "pause.fill" : "play.fill")
                    .frame(minWidth: 90)
            }
            .buttonStyle(.borderedProminent)
            .disabled(song == nil)
            Stepper("Speed \(percent)% · \(bpm) BPM", value: $speed, in: 0.25...1.5, step: 0.05)
                .fixedSize()
            Text(e.isFinished && !e.steps.isEmpty
                 ? "Finished! Played \(e.hitNotes.count) of \(e.noteCount) · missed \(e.missedCount) · wrong \(e.wrongCount)"
                 : timed.hasStarted
                    ? "Played \(e.hitNotes.count) of \(e.noteCount) · missed \(e.missedCount) · wrong \(e.wrongCount)"
                    : "Press Play: one bar of clicks, then the music moves on by itself")
                .font(.headline)
        }
    }

    @ViewBuilder private var staff: some View {
        if let song, timedMode {
            let e = timed.engine
            StaffView(song: song,
                      noteStates: e.noteStates,
                      wrongPitches: e.keyStates.filter { $0.value == .wrong }.map(\.key).sorted(),
                      scrollBeat: min(e.beat, song.durationBeats))
                .frame(height: 360)
        } else if let song {
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
        if !timedMode, let chord = engine.currentStep?.pitches, chord.count > 1, chord.contains(pitch) {
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
            case .noteOn(let pitch, _) where timedMode:
                if case .wrong = timed.noteOn(pitch) {
                    flash = .red
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { flash = .clear }
                }
            case .noteOff(let pitch) where timedMode:
                timed.noteOff(pitch)
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
        timed.onFinished = {
            let e = timed.engine
            if let songEntry {
                library.updateProgress(of: songEntry) { $0.recordCompleted(mistakes: e.wrongCount + e.missedCount) }
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
    /// In timed mode, missed notes count as mistakes too.
    private func recordAbandoned() { recordAbandoned(timed: timedMode) }

    private func recordAbandoned(timed isTimed: Bool) {
        guard let songEntry else { return }
        let e = timed.engine
        if isTimed, timed.hasStarted, !e.isFinished {
            library.updateProgress(of: songEntry) { $0.recordAbandoned(mistakes: e.wrongCount + e.missedCount) }
        } else if !isTimed, !engine.isFinished {
            library.updateProgress(of: songEntry) { $0.recordAbandoned(mistakes: engine.wrongCount) }
        }
    }

    private func open(_ entry: SongLibrary.Entry) {
        do {
            let loaded = try library.load(entry)
            releaseLatched()
            recordAbandoned()
            song = loaded
            songEntry = entry
            engine = WaitModeEngine(steps: PracticeSteps.make(from: loaded.notes))
            timed.load(loaded, speed: speed)
            loadError = nil
            lastSong = entry.url.lastPathComponent
        } catch {
            loadError = "Could not load \(entry.name): " + SongLibraryView.describe(error)
        }
    }
}
