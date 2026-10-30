import PianoCore
import SwiftUI

/// Main screen: the chosen song (a bundled sample or an imported .mid) on a scrolling grand staff, in wait mode
/// (the song waits for each note) or timed mode (it moves on at the chosen speed with a metronome; misses are counted).
/// Picking a song that has a lesson note shows the note first; the book button shows it again.
/// In timed mode, Listen plays the song by itself at the chosen speed.
/// In wait mode, tapping a clef practises only that hand; tapping a clef again goes back to both hands.
/// Dragging the staff sideways moves through the song (to the right = back); the bar slider and ◀ ▶ under it jump by bars.
/// Notes mode is a drill: random notes from the song, one at a time (one per staff with both hands), until another mode
/// is picked; the wait and timed runs are left where they were.
struct PracticeView: View {
    @EnvironmentObject private var midi: MIDIInputService
    @StateObject private var library = SongLibrary()
    @State private var song: Song?
    @State private var songEntry: SongLibrary.Entry?
    @State private var showLibrary = false
    /// The open song's lesson note (a Markdown file next to it), shown after the song is picked in the Songs sheet.
    @State private var note: PracticeNote?
    @State private var showNote = false
    /// Set when a song is picked; the note opens once the Songs sheet has gone (two sheets can't overlap).
    @State private var notePending = false
    /// The last song picked, as a file name ("twinkle.mid"); imported songs are looked up first.
    @AppStorage("lastSong") private var lastSong = ""
    @State private var engine = WaitModeEngine(steps: [])
    /// Wait mode with one hand only: the staff whose notes are waited for (nil = both hands).
    /// One-hand runs are not recorded in the song's progress.
    @State private var soloClef: Clef?
    /// Notes mode (the note drill) is on while this is set.
    @State private var drill: NoteDrill?
    /// The drill's hand: the staff its notes come from (nil = both, one note on each staff).
    @State private var drillClef: Clef?
    /// While the staff is being dragged: the beat it started from, and the beat now under the cursor.
    @State private var dragFrom: Double?
    @State private var dragBeat: Double?
    /// Timed mode was playing when the drag started, so it goes on (after a count-in) when the drag ends.
    @State private var resumeAfterDrag = false
    @State private var loadError: String?
    @State private var showPairing = false
    @State private var flash: Color = .clear
    /// On-screen chord keys stay held after the click/touch ends until the chord is complete,
    /// so chords can be played with a mouse (simulator, Mac). The real piano is unaffected.
    @State private var latched: Set<UInt8> = []
    @AppStorage("showKeyLabels") private var showKeyLabels = true
    @AppStorage("showFingers") private var showFingers = true
    @AppStorage("timedMode") private var timedMode = false
    /// Timed mode's speed as a fraction of the song's own tempo.
    @AppStorage("timedSpeed") private var speed = 0.75
    @StateObject private var timed = TimedSession()
    /// Listen: the app plays the song by itself at the timed-mode speed.
    @StateObject private var listen = AutoPlayer()
    /// Shown as a card over the screen when a song has been played to the end.
    @State private var result: PracticeResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                staff
                if song != nil, !listen.isPlaying, drill == nil { barControls }
                Spacer()
                KeyboardView(range: keyboardRange,
                             states: keyStates,
                             pressed: midi.pressed,
                             showLabels: showKeyLabels,
                             onPress: { midi.simulate(.noteOn(pitch: $0, velocity: 100)) },
                             onRelease: releaseOnScreenKey)
                    .frame(height: 180)
            }
            .padding()
            .background(flash.opacity(0.15).animation(.easeOut(duration: 0.3), value: flash))
            .overlay {
                if let result {
                    PracticeResultView(result: result,
                                       onAgain: { closeResult(); engine.reset(); timed.restart() },
                                       onClose: closeResult)
                }
            }
            .animation(.spring(duration: 0.35), value: result)
            .navigationTitle(song?.title ?? "PianoGuide")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { pauseAll(); showLibrary = true } label: { Label("Songs", systemImage: "music.note.list") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Restart") {
                        if drill != nil { startDrill(); return }
                        listen.stop(); closeResult(); releaseLatched(); recordAbandoned(); engine.reset(); timed.restart()
                    }
                }
                ToolbarItem(placement: modeSwitchPlacement) {
                    Picker("Mode", selection: mode) {
                        Text("Wait").tag(Mode.wait)
                        Text("Timed").tag(Mode.timed)
                        Text("Notes").tag(Mode.notes)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if note != nil {
                        Button { pauseAll(); showNote = true } label: { Label("Lesson Note", systemImage: "text.book.closed") }
                    }
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
                    Button { showFingers.toggle() } label: {
                        Label(showFingers ? "Hide Finger Numbers" : "Show Finger Numbers", systemImage: "textformat.123")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { pauseAll(); showPairing = true } label: { Label("Bluetooth MIDI", systemImage: "dot.radiowaves.left.and.right") }
                }
            }
            .sheet(isPresented: $showPairing, onDismiss: midi.connectAllSources) {
                BluetoothMIDIPairingView()
            }
            .sheet(isPresented: $showLibrary, onDismiss: {
                if notePending, note != nil { showNote = true }
                notePending = false
            }) {
                SongLibraryView(library: library, current: songEntry, onPick: { open($0); notePending = true })
            }
            .sheet(isPresented: $showNote) {
                if let note { PracticeNoteView(note: note, songName: song?.title ?? "") }
            }
        }
        .onAppear(perform: load)
        .onChange(of: library.imported) { _, imported in
            // The open song was deleted from the library: switch to a sample (nothing is recorded for it).
            guard let songEntry, !songEntry.isSample, !imported.contains(songEntry) else { return }
            self.songEntry = nil
            if let first = library.samples.first { open(first) }
        }
        .onChange(of: timedMode) { wasTimed, _ in
            installMIDIHandler()
            listen.stop()
            closeResult()
            releaseLatched()
            recordAbandoned(timed: wasTimed)
            engine.reset()
            timed.restart()
        }
        .onChange(of: speed) { _, new in timed.setSpeed(new); listen.setSpeed(new) }
    }

    private enum Mode { case wait, timed, notes }

    /// The mode switch. Notes is on top of the other two: leaving it goes back to the chosen mode where it was
    /// (wait and timed are only reset when switching between them, as before).
    private var mode: Binding<Mode> {
        Binding(get: { drill != nil ? .notes : timedMode ? .timed : .wait },
                set: { new in
                    if new == .notes { startDrill(); return }
                    drill = nil
                    releaseLatched()
                    timedMode = new == .timed
                })
    }

    /// The Mac (Catalyst) title bar doesn't show `.principal` items, so there the switch goes next to Restart.
    private var modeSwitchPlacement: ToolbarItemPlacement {
        #if targetEnvironment(macCatalyst)
        .topBarLeading
        #else
        .principal
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(midi.sourceNames.isEmpty ? "No MIDI keyboard connected. Tap the Bluetooth button, or use the keys below."
                                          : "Connected: " + midi.sourceNames.joined(separator: ", "))
                .font(.subheadline).foregroundColor(.secondary)
            if let loadError = loadError { Text(loadError).foregroundColor(.red) }
            if let drill {
                drillControls(drill)
            } else if timedMode {
                timedControls
            } else {
                Text((engine.isFinished && !engine.steps.isEmpty
                      ? "Finished! Wrong notes: \(engine.wrongCount)"
                      : "Step \(engine.currentIndex + 1) of \(engine.steps.count) · wrong notes: \(engine.wrongCount)")
                     + (soloClef == .treble ? " · right hand only" : soloClef == .bass ? " · left hand only" : ""))
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
            Button { listen.stop(); timed.togglePlay() } label: {
                Label(timed.isPlaying ? "Pause" : "Play", systemImage: timed.isPlaying ? "pause.fill" : "play.fill")
                    .frame(minWidth: 90)
            }
            .buttonStyle(.borderedProminent)
            .disabled(song == nil)
            Button { toggleListen() } label: {
                Label(listen.isPlaying ? "Stop" : "Listen", systemImage: listen.isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                    .frame(minWidth: 90)
            }
            .buttonStyle(.bordered)
            .disabled(song == nil)
            Stepper("Speed \(percent)% · \(bpm) BPM", value: $speed, in: 0.25...1.5, step: 0.05)
                .fixedSize()
            Text(listen.isPlaying ? "Listening: the song plays by itself at this speed"
                 : e.isFinished && !e.steps.isEmpty
                 ? "Finished! Played \(e.hitNotes.count) of \(e.noteCount) · missed \(e.missedCount) · wrong \(e.wrongCount)"
                 : timed.hasStarted
                    ? "Played \(e.hitNotes.count) of \(e.noteCount) · missed \(e.missedCount) · wrong \(e.wrongCount)"
                    : "Press Play: one bar of clicks, then the music moves on by itself")
                .font(.headline)
        }
    }

    private func drillControls(_ drill: NoteDrill) -> some View {
        HStack(spacing: 20) {
            Picker("Hand", selection: Binding(get: { drillClef }, set: setDrillClef)) {
                Text("Both Hands").tag(Clef?.none)
                Text("Right Hand").tag(Clef?.some(.treble))
                Text("Left Hand").tag(Clef?.some(.bass))
            }
            .pickerStyle(.segmented)
            .fixedSize()
            Text(drill.hasNotes ? "Found \(drill.foundCount) · wrong notes: \(drill.engine.wrongCount)"
                                : "This song has no notes for that hand")
                .font(.headline)
        }
    }

    @ViewBuilder private var staff: some View {
        if let drill {
            StaffView(song: Song(title: "", notes: drill.current),
                      noteStates: drill.engine.noteStates,
                      wrongPitches: drill.engine.keyStates.filter { $0.value == .wrong }.map(\.key).sorted(),
                      scrollBeat: 0,
                      showFingers: false,
                      showMeasures: false,
                      soloClef: drill.clef,
                      onClefTap: tapClef)
                .frame(height: 360)
        } else if let song, listen.isPlaying {
            StaffView(song: song,
                      noteStates: song.listenStates(atBeat: listen.beat),
                      wrongPitches: [],
                      scrollBeat: min(listen.beat, song.durationBeats),
                      showFingers: showFingers)
                .frame(height: 360)
        } else if let song, timedMode {
            let e = timed.engine
            StaffView(song: song,
                      noteStates: e.noteStates,
                      wrongPitches: e.keyStates.filter { $0.value == .wrong }.map(\.key).sorted(),
                      scrollBeat: dragBeat ?? min(e.beat, song.durationBeats),
                      showFingers: showFingers,
                      onDrag: dragStaff)
                .frame(height: 360)
        } else if let song {
            StaffView(song: song,
                      noteStates: engine.noteStates,
                      wrongPitches: engine.keyStates.filter { $0.value == .wrong }.map(\.key).sorted(),
                      scrollBeat: dragBeat ?? engine.currentStep?.startBeat ?? song.durationBeats,
                      showFingers: showFingers,
                      soloClef: soloClef,
                      onClefTap: tapClef,
                      onDrag: dragStaff)
                .animation(.easeInOut(duration: 0.3), value: engine.currentIndex)
                .frame(height: 360)
        }
    }

    private var keyStates: [UInt8: WaitModeEngine.KeyState] {
        if let drill { return drill.engine.keyStates }
        if let song, listen.isPlaying {
            return Dictionary(uniqueKeysWithValues: song.soundingPitches(atBeat: listen.beat).map { ($0, .correct) })
        }
        return timedMode ? timed.engine.keyStates : engine.keyStates
    }

    private var keyboardRange: ClosedRange<UInt8> {
        guard let range = song?.pitchRange else { return 48...84 }
        // Pad to whole octaves starting at C so the keyboard looks normal.
        let lo = UInt8(max(21, Int(range.lowerBound) / 12 * 12))
        let hi = UInt8(min(108, (Int(range.upperBound) / 12 + 1) * 12))
        return lo...hi
    }

    private func releaseOnScreenKey(_ pitch: UInt8) {
        let step = drill?.engine.currentStep ?? (timedMode ? nil : engine.currentStep)
        if let chord = step?.pitches, chord.count > 1, chord.contains(pitch) {
            latched.insert(pitch)
        } else {
            midi.simulate(.noteOff(pitch: pitch))
        }
    }

    /// Tapping a clef practises only that hand from the start; tapping either clef again goes back to both hands
    /// (so one staff always stays on). In the note drill it picks the drill's hand the same way.
    private func tapClef(_ clef: Clef) {
        guard let song else { return }
        if drill != nil { setDrillClef(drillClef == nil ? clef : nil); return }
        closeResult()
        releaseLatched()
        recordAbandoned()
        soloClef = soloClef == nil ? clef : nil
        engine = WaitModeEngine(steps: PracticeSteps.make(from: song.notes, clef: soloClef))
    }

    /// Dragging the staff moves through the song: to the right goes back, to the left goes ahead.
    /// Wait mode lands on the nearest step; timed mode pauses, and if it was playing goes on after a one-bar count-in.
    private func dragStaff(by beats: Double, ended: Bool) {
        guard song != nil else { return }
        beginMove()
        let target = min(max((dragFrom ?? 0) - beats, 0), lastStepBeat)
        if ended { move(to: target, nearest: true) } else { dragBeat = target }
    }

    /// ◀ slider ▶ under the staff: jump by whole bars. ◀ goes to the start of the bar (or the bar before, if
    /// already there); the slider shows the music while it moves and jumps when it is let go.
    private var barControls: some View {
        let starts = song?.barStartBeats ?? [0]
        let bar = song?.barIndex(atBeat: dragBeat ?? currentBeat) ?? 0
        let sliderBar = Binding<Double>(
            get: { Double(bar) },
            set: { beginMove(); dragBeat = starts[min(max(Int($0.rounded()), 0), starts.count - 1)] })
        return HStack(spacing: 16) {
            Button {
                guard let back = starts.last(where: { $0 < currentBeat - 1e-6 }) else { return }
                beginMove(); move(to: back, nearest: false)
            } label: { Label("Bar Back", systemImage: "backward.end.fill") }
            Slider(value: sliderBar, in: 0...Double(max(starts.count - 1, 1)), step: 1) { editing in
                if !editing, let dragBeat { move(to: dragBeat, nearest: false) }
            }
            .disabled(starts.count < 2)
            Button {
                guard let ahead = starts.first(where: { $0 > currentBeat + 1e-6 }) else { return }
                beginMove(); move(to: ahead, nearest: false)
            } label: { Label("Bar Ahead", systemImage: "forward.end.fill") }
            Text("Bar \(bar + 1) of \(starts.count)")
                .monospacedDigit()
                .frame(minWidth: 110, alignment: .leading)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
    }

    /// The beat at the cursor now (the current step in wait mode, the playhead in timed mode).
    private var currentBeat: Double {
        timedMode ? max(0, timed.engine.beat) : engine.currentStep?.startBeat ?? lastStepBeat
    }

    private var lastStepBeat: Double {
        (timedMode ? timed.engine.steps.last : engine.steps.last)?.startBeat ?? 0
    }

    /// Starts moving through the song (a drag, the slider or a bar button): closes the result card and pauses timed mode,
    /// remembering whether it was playing.
    private func beginMove() {
        guard dragFrom == nil else { return }
        closeResult()
        dragFrom = currentBeat
        resumeAfterDrag = timedMode && timed.isPlaying
        timed.pause()
    }

    /// Puts the song at `beat`. Wait mode lands on the nearest step (a drag) or the first step from there (a bar);
    /// timed mode goes on from there after a count-in if it was playing.
    private func move(to beat: Double, nearest: Bool) {
        let target = min(max(beat, 0), lastStepBeat)
        dragFrom = nil
        dragBeat = nil
        if timedMode {
            timed.seek(to: target, resume: resumeAfterDrag)
        } else {
            releaseLatched()
            engine.jump(to: nearest ? engine.stepIndex(nearest: target) : engine.stepIndex(from: target))
        }
    }

    /// Starts the note drill afresh for the open song (counts back to zero), pausing whatever else was going on.
    private func startDrill() {
        guard let song else { return }
        pauseAll()
        closeResult()
        releaseLatched()
        drill = NoteDrill(song: song, clef: drillClef)
    }

    private func setDrillClef(_ clef: Clef?) {
        drillClef = clef
        startDrill()
    }

    private func pauseAll() {
        timed.pause()
        listen.stop()
    }

    private func toggleListen() {
        if listen.isPlaying { listen.stop(); return }
        guard let song else { return }
        timed.pause()
        closeResult()
        listen.play(song, speed: speed)
    }

    private func releaseLatched() {
        let pitches = latched
        latched = []
        pitches.forEach { midi.simulate(.noteOff(pitch: $0)) }
    }

    private func load() {
        installMIDIHandler()
        timed.onFinished = {
            let e = timed.engine
            finish(PracticeResult(timed: true, total: e.noteCount, wrong: e.wrongCount, missed: e.missedCount))
        }
        guard song == nil else { return }
        let all = library.imported + library.allSamples
        guard let entry = all.first(where: { $0.url.lastPathComponent == lastSong }) ?? library.samples.first else {
            loadError = "Sample song missing from app bundle"
            return
        }
        open(entry)
    }

    /// Routes note events to the current mode. The handler keeps the `timedMode` value from when it was made
    /// (it is a copy of this view), so it is made again whenever the mode changes.
    private func installMIDIHandler() {
        midi.onEvent = { event in
            // While the song plays itself, keys are not judged.
            if listen.isPlaying, case .noteOn = event { return }
            if drill != nil {
                handleDrill(event)
                return
            }
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
                    if engine.isFinished {
                        finish(PracticeResult(timed: false, total: engine.noteCount, wrong: engine.wrongCount))
                    }
                    DispatchQueue.main.async(execute: releaseLatched)
                default: break
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { flash = .clear }
            case .noteOff(let pitch):
                engine.noteOff(pitch)
            }
        }
    }

    /// Note drill: same feedback as wait mode, and it never finishes. Releases also go to the wait and timed engines,
    /// so a key held down while switching modes doesn't stay colored there.
    private func handleDrill(_ event: MIDIInputService.Event) {
        switch event {
        case .noteOn(let pitch, _):
            switch drill?.noteOn(pitch) {
            case .wrong: flash = .red
            case .stepCompleted:
                flash = .green
                DispatchQueue.main.async(execute: releaseLatched)
            default: break
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { flash = .clear }
        case .noteOff(let pitch):
            drill?.noteOff(pitch)
            engine.noteOff(pitch)
            timed.noteOff(pitch)
        }
    }

    /// The song was played to the end: record it and show the result card.
    private func finish(_ finished: PracticeResult) {
        let skipped = finished.timed ? timed.engine.skippedAhead : engine.skippedAhead
        if let songEntry, finished.timed || soloClef == nil, !skipped {
            library.updateProgress(of: songEntry) { $0.recordCompleted(mistakes: finished.mistakes, notes: finished.total) }
        }
        result = finished
    }

    private func closeResult() { result = nil }

    /// Leaving a song before the end still counts its wrong notes towards the difficult mark.
    /// In timed mode, missed notes count as mistakes too.
    private func recordAbandoned() { recordAbandoned(timed: timedMode) }

    private func recordAbandoned(timed isTimed: Bool) {
        guard let songEntry else { return }
        let e = timed.engine
        if isTimed, timed.hasStarted, !e.isFinished {
            library.updateProgress(of: songEntry) { $0.recordAbandoned(mistakes: e.wrongCount + e.missedCount, notes: e.noteCount) }
        } else if !isTimed, soloClef == nil, !engine.isFinished {
            library.updateProgress(of: songEntry) { $0.recordAbandoned(mistakes: engine.wrongCount, notes: engine.noteCount) }
        }
    }

    private func open(_ entry: SongLibrary.Entry) {
        do {
            let loaded = try library.load(entry)
            listen.stop()
            closeResult()
            releaseLatched()
            recordAbandoned()
            song = loaded
            songEntry = entry
            note = library.note(for: entry)
            soloClef = nil
            engine = WaitModeEngine(steps: PracticeSteps.make(from: loaded.notes))
            timed.load(loaded, speed: speed)
            if drill != nil { drill = NoteDrill(song: loaded, clef: drillClef) }
            loadError = nil
            lastSong = entry.url.lastPathComponent
        } catch {
            loadError = "Could not load \(entry.name): " + SongLibraryView.describe(error)
        }
    }
}
