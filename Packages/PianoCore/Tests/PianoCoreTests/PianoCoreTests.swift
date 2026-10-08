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
