import XCTest
@testable import PianoCore

final class MIDIFileTests: XCTestCase {
    func testRoundTripSampleSong() throws {
        let original = SampleSongs.twinkle
        let parsed = try MIDIFileParser.parse(MIDIFileWriter.write(original))
        XCTAssertEqual(parsed.title, "Twinkle Twinkle")
        XCTAssertEqual(parsed.notes.count, original.notes.count)
        XCTAssertEqual(parsed.notes.map(\.pitch), original.notes.map(\.pitch))
        XCTAssertEqual(parsed.notes.map(\.hand), original.notes.map(\.hand), "hands from tracks")
        XCTAssertEqual(parsed.tempoMap[0].bpm, 100, accuracy: 0.01)
        XCTAssertEqual(parsed.notes.first?.startBeat, 0)
        XCTAssertEqual(parsed.notes.last?.startBeat, 14)
    }

    func testBundledSamplesMatchGenerator() throws {
        // App/Resources/SampleSongs/*.mid must be regenerated (scripts/check-core.sh --write-samples) after changing SampleSongs.
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("../../App/Resources/SampleSongs").standardized
        for (name, song) in SampleSongs.all {
            XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(name + ".mid")), MIDIFileWriter.write(song), name)
        }
    }

    func testEveryBundledSampleHasANote() throws {
        // Each sample "x.mid" has its lesson in "x.md" next to it, with a title and some text.
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("../../App/Resources/SampleSongs").standardized
        for (name, _) in SampleSongs.all {
            let note = PracticeNote(markdown: try String(contentsOf: dir.appendingPathComponent(name + ".md"), encoding: .utf8))
            XCTAssertNotNil(note.title, name)
            XCTAssertFalse(note.blocks.isEmpty, name)
            // At least one music example, and every one readable.
            XCTAssertTrue(note.blocks.contains { if case .staff = $0 { return true } else { return false } }, name)
            for case .invalidStaff(let reason) in note.blocks { XCTFail("\(name): \(reason)") }
        }
    }

    func testPracticeNoteMarkdown() {
        let note = PracticeNote(markdown: """
            # Pairs

            Keep your **wrist** still
            and relaxed.

            ## Watch for
            - finger 4
              is the weakest
            * curve your fingers
            Last line.
            """)
        XCTAssertEqual(note.title, "Pairs")
        XCTAssertEqual(note.blocks, [
            .paragraph("Keep your **wrist** still and relaxed."),
            .heading("Watch for"),
            .bullet("finger 4 is the weakest"),
            .bullet("curve your fingers"),
            .paragraph("Last line."),
        ])
        XCTAssertNil(PracticeNote(markdown: "Just text").title)
        XCTAssertTrue(PracticeNote(markdown: "\n\n").isEmpty)
    }

    func testStaffExample() throws {
        let note = PracticeNote(markdown: """
            Text before.
            ```staff
            right: C4/1 E4/3! G4/5:2
            left: C3/5+G3/1:4
            time: 4/4
            caption: The C chord
            ```
            ```staff
            right: H4
            ```
            """)
        XCTAssertEqual(note.blocks.count, 3)
        guard case .staff(let example) = note.blocks[1] else { return XCTFail("no staff") }
        XCTAssertEqual(example.notes.map(\.pitch), [48, 55, 60, 64, 67])
        XCTAssertEqual(example.notes.map(\.startBeat), [0, 0, 0, 1, 2])
        XCTAssertEqual(example.notes.map(\.hand), [.left, .left, .right, .right, .right])
        XCTAssertEqual(example.notes.map(\.finger), [5, 1, 1, 3, 5])
        XCTAssertEqual(example.notes.last?.durationBeats, 2)
        XCTAssertEqual(example.highlighted, [3], "E4")
        XCTAssertEqual(example.caption, "The C chord")
        XCTAssertEqual(example.song.durationBeats, 4)
        guard case .invalidStaff = note.blocks[2] else { return XCTFail("bad note name should be reported") }

        let rest = try StaffExample("right: r:2 F#4:2\ntime: 3/4")
        XCTAssertEqual(rest.notes.map(\.pitch), [66])
        XCTAssertEqual(rest.notes.first?.startBeat, 2)
        XCTAssertEqual(rest.timeSignature.numerator, 3)
        XCTAssertEqual(try StaffExample("left: C3+G3:4! E3").highlighted, [0, 1], "! after the length: whole chord")
        XCTAssertThrowsError(try StaffExample("right: C4/6"))
        XCTAssertThrowsError(try StaffExample("caption: no notes"))
    }

    func testFingersRoundTrip() throws {
        // Two fingered notes in one chord, plus a note without a finger, in both file formats.
        let song = Song(title: "Fingers", notes: [
            NoteEvent(id: 0, pitch: 60, startBeat: 0, durationBeats: 1, velocity: 80, hand: .right, finger: 1),
            NoteEvent(id: 1, pitch: 64, startBeat: 0, durationBeats: 1, velocity: 80, hand: .right, finger: 3),
            NoteEvent(id: 2, pitch: 62, startBeat: 1, durationBeats: 1, velocity: 80, hand: .right),
            NoteEvent(id: 3, pitch: 48, startBeat: 1, durationBeats: 1, velocity: 80, hand: .left, finger: 5),
        ])
        for singleTrack in [false, true] {
            let parsed = try MIDIFileParser.parse(MIDIFileWriter.write(song, singleTrack: singleTrack))
            XCTAssertEqual(parsed.notes.map(\.pitch), [60, 64, 48, 62])
            XCTAssertEqual(parsed.notes.map(\.finger), [1, 3, 5, nil], "singleTrack: \(singleTrack)")
        }
    }

    func testPositionSongs() {
        XCTAssertEqual(FivePosition.d.pitch(finger: 3, hand: .right), 66, "F#4")
        XCTAssertEqual(FivePosition.c.pitch(finger: 5, hand: .left), 48, "C3")
        XCTAssertEqual(FivePosition.f.pitch(finger: 5, hand: .left), 41, "F2")
        XCTAssertEqual(PositionPractice.series.map(\.name),
                       ["1. C position", "2. C + F positions", "3. C + F + D positions"])
        let song = PositionPractice.series[2].rightHand
        XCTAssertEqual(song.durationBeats, 127.8, accuracy: 0.001, "C, F, D, C: 32 bars, ending on a whole note")
        XCTAssertEqual(PositionPractice.series[0].rightHand.durationBeats, 63.8, accuracy: 0.001, "C twice: 16 bars")
        // Bar starts show fingers: C position starts on C4 with 1, F on F4 with 1, D on D4 with 1.
        let fingered = song.notes.filter { $0.finger != nil }
        XCTAssertEqual(fingered.count, 32)
        XCTAssertEqual(fingered.filter { [0, 32, 64, 96].contains($0.startBeat) }.map(\.pitch), [60, 65, 62, 60])
        for practice in PositionPractice.series {
            XCTAssertFalse(practice.rightHand.notes.contains { $0.pitch % 12 == 10 }, "no B flat")
            XCTAssertFalse(practice.bothHands.notes.contains { $0.pitch % 12 == 10 }, "no B flat")
        }
    }

    func testFingerPractices() {
        XCTAssertEqual(FingerPractice.allCases.map(\.name),
                       ["Fingers 1 · Pairs", "Fingers 2 · Skips",
                        "Fingers 3 · Mirror (hands together)", "Fingers 4 · Parallel (hands together)"])
        for practice in FingerPractice.allCases {
            let song = practice.song
            XCTAssertEqual(song.durationBeats, 63.8, accuracy: 0.001, "\(practice): 16 bars")
            XCTAssertTrue(song.notes.allSatisfy { $0.finger != nil }, "\(practice): every note has a finger")
            XCTAssertFalse(song.notes.contains { NoteName.isBlackKey($0.pitch) }, "\(practice): white keys only")
        }
        // Mirror: same fingers (C4 with G3); parallel: same note names (C4 with C3).
        let mirror = FingerPractice.mirror.song.notes.filter { $0.startBeat == 0 }
        XCTAssertEqual(mirror.map(\.finger), [1, 1])
        XCTAssertEqual(mirror.map(\.pitch), [55, 60])
        let parallel = FingerPractice.parallel.song.notes.filter { $0.startBeat == 0 }
        XCTAssertEqual(parallel.map(\.pitch), [48, 60])
        XCTAssertEqual(parallel.map(\.finger), [5, 1])
        // Pairs: the left hand starts at bar 9.
        XCTAssertEqual(FingerPractice.pairs.song.notes.first { $0.hand == .left }?.startBeat, 32)
    }

    func testHandsPractices() {
        XCTAssertEqual(HandsPractice.allCases.map(\.name),
                       ["Hands 1 · Taking turns", "Hands 2 · One hand holds", "Hands 3 · Two against one",
                        "Hands 4 · Different shapes", "Hands 5 · Off the beat", "Hands 6 · Eighths against quarters"])
        for practice in HandsPractice.allCases {
            let song = practice.song
            XCTAssertEqual((song.durationBeats / 4).rounded(.up), 16, "\(practice): 16 bars")
            XCTAssertTrue(song.notes.allSatisfy { $0.finger != nil }, "\(practice): every note has a finger")
            XCTAssertFalse(song.notes.contains { NoteName.isBlackKey($0.pitch) }, "\(practice): white keys only")
            XCTAssertTrue(song.notes.contains { $0.hand == .left } && song.notes.contains { $0.hand == .right })
        }
        // Taking turns: the hands start a note at the same time only in the last bar.
        let turns = HandsPractice.turns.song.notes
        let rightStarts = Set(turns.filter { $0.hand == .right }.map(\.startBeat))
        XCTAssertEqual(Set(turns.filter { $0.hand == .left }.map(\.startBeat)).intersection(rightStarts), [60])
        // Off the beat: the left hand comes in on beat 2 (a rest first); the swapped half starts at bar 9.
        let offBeat = HandsPractice.offTheBeat.song.notes
        XCTAssertEqual(offBeat.first { $0.hand == .left }?.startBeat, 1)
        XCTAssertEqual(offBeat.filter { $0.startBeat == 32 }.map(\.hand), [.left])
        // Swapped half: the same note names, an octave apart (bar 1 right C4 → bar 9 left C3).
        let holding = HandsPractice.holding.song.notes
        XCTAssertEqual(holding.filter { $0.startBeat == 32 }.map(\.pitch), [48, 60])
        XCTAssertEqual(holding.filter { $0.startBeat == 32 && $0.hand == .left }.first?.durationBeats ?? 0, 0.95,
                       accuracy: 0.001, "left hand plays the quarters")
    }

    func testRunningStatusVelocityZeroAndSingleTrackHandSplit() throws {
        // Format 0, 96 ticks per quarter; C4 then G3 using running status.
        let track: [UInt8] = [
            0x00, 0x90, 60, 100,   // note on C4
            0x60, 60, 0,           // running status, vel 0 = off after 1 beat
            0x00, 55, 90,          // G3 on
            0x60, 55, 0,           // G3 off
            0x00, 0xFF, 0x2F, 0x00,
        ]
        var bytes = Array("MThd".utf8) + [0, 0, 0, 6, 0, 0, 0, 1, 0, 96]
        bytes += Array("MTrk".utf8) + [0, 0, 0, UInt8(track.count)] + track
        let song = try MIDIFileParser.parse(Data(bytes))
        XCTAssertEqual(song.notes.count, 2)
        XCTAssertEqual(song.notes[0].pitch, 60)
        XCTAssertEqual(song.notes[0].durationBeats, 1)
        XCTAssertEqual(song.notes[1].pitch, 55)
        XCTAssertEqual(song.notes[1].startBeat, 1)
        XCTAssertEqual(song.notes.map(\.hand), [.right, .left], "split at middle C")
    }

    func testTestSongsMatchGeneratorAndParseBack() throws {
        // TestSongs/*.mid must be regenerated (scripts/check-core.sh --write-test-songs TestSongs) after changing TestSongs.
        let dir = URL(fileURLWithPath: #filePath).appendingPathComponent("../../../../../TestSongs").standardized
        for (name, song, singleTrack) in TestSongs.all {
            let data = MIDIFileWriter.write(song, singleTrack: singleTrack)
            XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(name + ".mid")), data, name)
            let parsed = try MIDIFileParser.parse(data)
            XCTAssertEqual(parsed.title, song.title)
            XCTAssertEqual(parsed.timeSignatures, song.timeSignatures, name)
            XCTAssertEqual(parsed.tempoMap, song.tempoMap, name)
            XCTAssertEqual(parsed.notes.map(\.pitch), song.notes.map(\.pitch), name)
            XCTAssertEqual(parsed.notes.map(\.startBeat), song.notes.map(\.startBeat), name)
            // Two tracks give the hands directly; the single-track file is split at middle C, which matches here too.
            XCTAssertEqual(parsed.notes.map(\.hand), song.notes.map(\.hand), name)
        }
        XCTAssertEqual(TestSongs.minuetInG.timeSignatures.first?.numerator, 3)
        XCTAssertEqual(PracticeSteps.make(from: TestSongs.odeToJoy.notes).first?.pitches.count, 4, "C3+E3+G3 with E4")
    }

    func testRejectsGarbage() {
        XCTAssertThrowsError(try MIDIFileParser.parse(Data("hello world".utf8))) { error in
            XCTAssertEqual(error as? MIDIFileParser.ParseError, .notAMIDIFile)
        }
    }
}

final class SongTests: XCTestCase {
    func testTempoMapBeatsToSeconds() {
        let song = Song(title: "t", tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: 500_000),
                                                TempoChange(beat: 4, microsecondsPerQuarter: 1_000_000)], notes: [])
        XCTAssertEqual(song.seconds(atBeat: 2), 1.0, "2 beats at 120 BPM")
        XCTAssertEqual(song.seconds(atBeat: 4), 2.0)
        XCTAssertEqual(song.seconds(atBeat: 6), 4.0, "then 2 beats at 60 BPM")
        XCTAssertEqual(Song(title: "d", notes: []).seconds(atBeat: 1), 0.5, "default 120 BPM")
    }

    func testNoteNames() {
        XCTAssertEqual(NoteName.of(60), "C4")
        XCTAssertEqual(NoteName.of(21), "A0")
        XCTAssertEqual(NoteName.of(61), "C#4")
        XCTAssertTrue(NoteName.isBlackKey(61))
        XCTAssertFalse(NoteName.isBlackKey(60))
    }
}

final class WaitModeTests: XCTestCase {
    func testPracticeStepsGroupChords() {
        let notes = [
            NoteEvent(id: 0, pitch: 60, startBeat: 0, durationBeats: 1, velocity: 80, hand: .right),
            NoteEvent(id: 1, pitch: 64, startBeat: 0.01, durationBeats: 1, velocity: 80, hand: .right),
            NoteEvent(id: 2, pitch: 48, startBeat: 0, durationBeats: 1, velocity: 80, hand: .left),
            NoteEvent(id: 3, pitch: 62, startBeat: 1, durationBeats: 1, velocity: 80, hand: .right),
        ]
        let all = PracticeSteps.make(from: notes)
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].pitches, [60, 64, 48], "first step is a 3-note chord")
        XCTAssertEqual(PracticeSteps.make(from: notes, hands: [.right])[0].pitches, [60, 64], "hand filter")
    }

    func testEngine() {
        let notes = [
            NoteEvent(id: 0, pitch: 60, startBeat: 0, durationBeats: 1, velocity: 80),
            NoteEvent(id: 1, pitch: 64, startBeat: 0, durationBeats: 1, velocity: 80),
            NoteEvent(id: 2, pitch: 67, startBeat: 1, durationBeats: 1, velocity: 80),
        ]
        var engine = WaitModeEngine(steps: PracticeSteps.make(from: notes))
        XCTAssertEqual(engine.noteOn(62), .wrong(pitch: 62))
        XCTAssertEqual(engine.noteOn(60), .correct(pitch: 60), "half the chord")
        XCTAssertEqual(engine.currentIndex, 0, "still waiting on chord")
        XCTAssertEqual(engine.noteOn(64), .stepCompleted(index: 0))
        XCTAssertEqual(engine.noteOn(67), .stepCompleted(index: 1))
        XCTAssertTrue(engine.isFinished)
        XCTAssertEqual(engine.noteOn(60), .finished)
        XCTAssertEqual(engine.wrongCount, 1)
    }

    func testReleasedChordNoteMustBePressedAgain() {
        let notes = [
            NoteEvent(id: 0, pitch: 60, startBeat: 0, durationBeats: 1, velocity: 80),
            NoteEvent(id: 1, pitch: 64, startBeat: 0, durationBeats: 1, velocity: 80),
        ]
        var engine = WaitModeEngine(steps: PracticeSteps.make(from: notes))
        _ = engine.noteOn(60)
        engine.noteOff(60)
        XCTAssertEqual(engine.noteOn(64), .correct(pitch: 64))
        XCTAssertEqual(engine.currentIndex, 0)
    }

    func testKeyStatesKeepVerdictFromPressTime() {
        let notes = [
            NoteEvent(id: 0, pitch: 60, startBeat: 0, durationBeats: 1, velocity: 80),
            NoteEvent(id: 1, pitch: 64, startBeat: 0, durationBeats: 1, velocity: 80),
            NoteEvent(id: 2, pitch: 67, startBeat: 1, durationBeats: 1, velocity: 80),
        ]
        var engine = WaitModeEngine(steps: PracticeSteps.make(from: notes))
        XCTAssertEqual(engine.keyStates, [:], "no hints before a mistake")
        _ = engine.noteOn(60)
        XCTAssertEqual(engine.keyStates, [60: .correct])
        _ = engine.noteOn(62)
        XCTAssertEqual(engine.keyStates, [60: .correct, 62: .wrong, 64: .missed], "wrong note shows the missing key")
        engine.noteOff(62)
        XCTAssertEqual(engine.keyStates, [60: .correct, 64: .missed], "hint stays after releasing the wrong key")
        _ = engine.noteOn(64)
        XCTAssertEqual(engine.keyStates, [60: .correct, 64: .correct], "held keys stay green after the step moves on")
        engine.noteOff(60)
        engine.noteOff(64)
        XCTAssertEqual(engine.keyStates, [:])
    }
}

final class SongProgressTests: XCTestCase {
    func testCompletedAndDifficult() throws {
        var progress = SongProgress()
        XCTAssertFalse(progress.isCompleted)
        XCTAssertFalse(progress.isDifficult)

        progress.recordAbandoned(mistakes: 0)
        XCTAssertNil(progress.mistakes, "leaving without a mistake records nothing")
        progress.recordAbandoned(mistakes: 6)
        XCTAssertTrue(progress.isDifficult)
        XCTAssertFalse(progress.isCompleted)

        progress.recordCompleted(mistakes: 2)
        XCTAssertTrue(progress.isCompleted)
        XCTAssertFalse(progress.isDifficult, "finishing with few mistakes clears the mark")
        progress.recordAbandoned(mistakes: 1)
        XCTAssertEqual(progress.mistakes, 2, "an unfinished attempt only raises the count")

        progress.recordCompleted(mistakes: 5)
        XCTAssertEqual(progress.timesCompleted, 2)
        XCTAssertTrue(progress.isDifficult)

        let decoded = try JSONDecoder().decode(SongProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(decoded, progress)
    }

    func testMarkIsSavedAndOldDataStillLoads() throws {
        var progress = SongProgress()
        progress.mark = .interesting
        progress.recordCompleted(mistakes: 7)
        XCTAssertEqual(progress.mark, .interesting, "playing doesn't change the user's mark")
        let decoded = try JSONDecoder().decode(SongProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(decoded.mark, .interesting)

        let old = try JSONDecoder().decode(SongProgress.self, from: Data(#"{"timesCompleted":1,"mistakes":2}"#.utf8))
        XCTAssertNil(old.mark)
        XCTAssertEqual(old.timesCompleted, 1)
    }
}

final class StaffLayoutTests: XCTestCase {
    private func note(_ pitch: UInt8, _ hand: Hand = .unknown) -> NoteEvent {
        NoteEvent(id: 0, pitch: pitch, startBeat: 0, durationBeats: 1, velocity: 80, hand: hand)
    }

    func testPositionsOnTrebleAndBass() {
        XCTAssertEqual(StaffLayout.place(note(64)), StaffNote(clef: .treble, position: 0, sharp: false))  // E4 bottom line
        XCTAssertEqual(StaffLayout.place(note(77)), StaffNote(clef: .treble, position: 8, sharp: false))  // F5 top line
        XCTAssertEqual(StaffLayout.place(note(60)).position, -2)                                          // middle C: ledger line
        XCTAssertEqual(StaffLayout.place(note(66)), StaffNote(clef: .treble, position: 1, sharp: true))   // F#4
        XCTAssertEqual(StaffLayout.place(note(43)), StaffNote(clef: .bass, position: 0, sharp: false))    // G2 bottom line
        XCTAssertEqual(StaffLayout.place(note(57)).position, 8)                                           // A3 top line
        XCTAssertEqual(StaffLayout.place(note(60, .left)), StaffNote(clef: .bass, position: 10, sharp: false))  // C4 above bass staff
    }

    func testLedgerLinesAndStems() {
        XCTAssertEqual(StaffLayout.place(note(60)).ledgerLines, [-2])
        XCTAssertEqual(StaffLayout.place(note(57, .right)).ledgerLines, [-2, -4])   // A3 on treble
        XCTAssertEqual(StaffLayout.place(note(81)).ledgerLines, [10])               // A5
        XCTAssertEqual(StaffLayout.place(note(65)).ledgerLines, [])
        XCTAssertTrue(StaffLayout.place(note(67)).stemUp)                           // G4, below middle line
        XCTAssertFalse(StaffLayout.place(note(71)).stemUp)                          // B4, middle line
    }

    func testNoteValues() {
        XCTAssertEqual(NoteValue.from(beats: 0.95), .quarter)
        XCTAssertEqual(NoteValue.from(beats: 1.9), .half)
        XCTAssertEqual(NoteValue.from(beats: 3.8), .whole)
        XCTAssertEqual(NoteValue.from(beats: 0.5), .eighth)
        XCTAssertEqual(NoteValue.from(beats: 0.2), .sixteenth)
    }

    func testBarlines() {
        let twinkle = SampleSongs.twinkle   // 16 beats of 4/4 (no time signature in the file)
        XCTAssertEqual(twinkle.barlineBeats, [4, 8, 12, 16])
        var waltz = Song(title: "", timeSignatures: [TimeSignature(beat: 0, numerator: 3, denominator: 4)],
                         notes: [NoteEvent(id: 0, pitch: 60, startBeat: 0, durationBeats: 9, velocity: 80)])
        XCTAssertEqual(waltz.barlineBeats, [3, 6, 9])
        waltz.timeSignatures.append(TimeSignature(beat: 6, numerator: 6, denominator: 8))
        XCTAssertEqual(waltz.barlineBeats, [3, 6, 9])
        XCTAssertEqual(TimeSignature(beat: 0, numerator: 4, denominator: 4).beatsPerBar, 4)
        XCTAssertEqual(TimeSignature(beat: 0, numerator: 3, denominator: 4).beatsPerBar, 3)
        XCTAssertEqual(TimeSignature(beat: 0, numerator: 6, denominator: 8).beatsPerBar, 3)
    }

    func testNoteStates() {
        let song = SampleSongs.twinkle      // step 0: C3+C4, step 1: C4
        var engine = WaitModeEngine(steps: PracticeSteps.make(from: song.notes))
        XCTAssertEqual(engine.noteStates, [0: .next, 1: .next])
        _ = engine.noteOn(60)
        XCTAssertEqual(engine.noteStates, [0: .next, 1: .played])
        _ = engine.noteOn(50)
        XCTAssertEqual(engine.noteStates, [0: .missed, 1: .played])
        _ = engine.noteOn(48)
        XCTAssertEqual(engine.noteStates, [0: .played, 1: .played, 2: .next])
    }
}

final class TimedModeTests: XCTestCase {
    private let notes = [
        NoteEvent(id: 0, pitch: 60, startBeat: 0, durationBeats: 1, velocity: 80),
        NoteEvent(id: 1, pitch: 64, startBeat: 0, durationBeats: 1, velocity: 80),
        NoteEvent(id: 2, pitch: 62, startBeat: 1, durationBeats: 1, velocity: 80),
        NoteEvent(id: 3, pitch: 62, startBeat: 1.5, durationBeats: 1, velocity: 80),
        NoteEvent(id: 4, pitch: 67, startBeat: 3, durationBeats: 1, velocity: 80),
    ]

    func testHitsMissesAndWrongNotes() {
        var engine = TimedModeEngine(steps: PracticeSteps.make(from: notes), early: 0.5, late: 0.5, startBeat: -4)
        XCTAssertEqual(engine.noteOn(60), .wrong(pitch: 60), "too early, during the count-in")
        engine.advance(to: -0.4)
        XCTAssertEqual(engine.noteOn(60), .hit(noteID: 0), "a little early is fine")
        XCTAssertEqual(engine.noteStates[1], .next)
        engine.advance(to: 0.6)
        XCTAssertEqual(engine.missedNotes, [1], "the other chord note was never played")
        XCTAssertEqual(engine.judgedCount, 1)
        engine.advance(to: 1.3)
        XCTAssertEqual(engine.noteOn(62), .hit(noteID: 3), "the closer of two D's")
        XCTAssertEqual(engine.noteOn(62), .hit(noteID: 2), "then the other one")
        XCTAssertEqual(engine.noteOn(62), .wrong(pitch: 62), "no D left in the window")
        XCTAssertEqual(engine.keyStates, [60: .correct, 62: .wrong], "held keys keep their last verdict")
        engine.noteOff(62)
        engine.advance(to: 10)
        XCTAssertTrue(engine.isFinished)
        XCTAssertEqual(engine.missedNotes, [1, 4])
        XCTAssertEqual(engine.wrongCount, 2)
        XCTAssertEqual(engine.noteStates, [0: .played, 1: .missed, 2: .played, 3: .played, 4: .missed])
        XCTAssertEqual(engine.noteCount, 5)
    }

    func testLateSideIsWider() {
        var engine = TimedModeEngine(steps: PracticeSteps.make(from: notes), startBeat: -4)
        engine.advance(to: -0.6)
        XCTAssertEqual(engine.noteOn(60), .wrong(pitch: 60), "more than half a beat early")
        engine.advance(to: 0.7)
        XCTAssertEqual(engine.noteOn(64), .hit(noteID: 1), "0.7 beats late still counts")
        engine.advance(to: 0.8)
        XCTAssertEqual(engine.missedNotes, [0], "judged once the late side has passed")
    }

    func testPlayheadFollowsTempoAndSpeed() {
        let song = Song(title: "t", tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: 500_000),
                                                TempoChange(beat: 4, microsecondsPerQuarter: 1_000_000)], notes: [])
        XCTAssertEqual(song.beat(after: 1, from: 0, speed: 1), 2, "120 BPM")
        XCTAssertEqual(song.beat(after: 1, from: -4, speed: 0.5), -3, "count-in uses the first tempo, at half speed")
        XCTAssertEqual(song.beat(after: 1, from: 5, speed: 1), 6, "60 BPM after beat 4")
    }
}
