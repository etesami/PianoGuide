import XCTest
@testable import PianoCore

/// A made-up song shaped like the user's Setaregan file (the real notes stay out of the repo): 116 bars of 3/4,
/// bars 1–2 a left-hand intro, a pickup (rest, two notes) at the start of every 4-bar group, otherwise three notes
/// a bar; a note tied over bars 64–65; the last note tied from bar 114 to the end over a low note held in bars 115–116.
/// Left hand: a low note on 1 and a two-note chord on 2 and 3. Every note has a finger.
enum FakeSetaregaan {
    static let song: Song = make()

    static func make(bars: Int = 116, numerator: Int = 3, leftHand: Bool = true) -> Song {
        var notes: [NoteEvent] = []
        func add(_ pitch: UInt8, _ start: Double, _ beats: Double, _ hand: Hand, _ finger: Int) {
            notes.append(NoteEvent(id: 0, pitch: pitch, startBeat: start, durationBeats: beats * 0.95, velocity: 80,
                                   hand: hand, finger: finger))
        }
        for bar in 1...bars {
            let s = Double(bar - 1) * 3
            if bar >= 3 {
                switch bar {
                case 64: add(60, s, 1, .right, 1); add(62, s + 1, 5, .right, 2)    // tied into bar 65
                case 65, 115, 116: break
                case 114: add(60, s, 1, .right, 1); add(64, s + 1, 8, .right, 3)  // tied to the end
                case _ where (bar - 3) % 4 == 0: add(64, s + 1, 1, .right, 3); add(65, s + 2, 1, .right, 4)
                default: for i in 0..<3 { add(UInt8(67 + i), s + Double(i), 1, .right, i + 1) }
                }
            }
            guard leftHand else { continue }
            if bar == 115 { add(40, s, 6, .left, 5); continue }
            if bar == 116 { continue }
            add(bar % 2 == 0 ? 41 : 40, s, 1, .left, 5)
            for beat in [1.0, 2.0] { add(55, s + beat, 1, .left, 3); add(59, s + beat, 1, .left, 1) }
        }
        notes.sort { ($0.startBeat, $0.pitch) < ($1.startBeat, $1.pitch) }
        return Song(title: "Fake", tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: 600_000)],
                    timeSignatures: [TimeSignature(beat: 0, numerator: numerator, denominator: 4)],
                    notes: notes.enumerated().map { i, n in
                        NoteEvent(id: i, pitch: n.pitch, startBeat: n.startBeat, durationBeats: n.durationBeats,
                                  velocity: n.velocity, hand: n.hand, finger: n.finger)
                    })
    }
}

final class SetaregaanPieceTests: XCTestCase {
    typealias Piece = SetaregaanPiece
    let source = FakeSetaregaan.song

    func testFileCheck() {
        XCTAssertNil(Piece.problem(with: source))
        XCTAssertNotNil(Piece.problem(with: FakeSetaregaan.make(bars: 40)), "too short")
        XCTAssertNotNil(Piece.problem(with: FakeSetaregaan.make(numerator: 4)), "not 3/4")
        XCTAssertNotNil(Piece.problem(with: FakeSetaregaan.make(leftHand: false)), "one hand only")
        XCTAssertEqual(Piece.file.id, "ghoghaye-setaregan")
    }

    func testSectionsAreWholeBarsOf3_4WithFingers() {
        for section in Piece.Section.allCases {
            for left in [Piece.Left.root, .rootAndChord, .full] {
                for right in [Piece.Right.melody, .firstNotes] {
                    let song = Piece.song(section, from: source, left: left, right: right)
                    let name = song.title
                    XCTAssertEqual(song.timeSignatures.first?.numerator, 3, name)
                    XCTAssertEqual(song.tempoMap[0].bpm, 100, accuracy: 0.01, name)
                    XCTAssertTrue(song.notes.allSatisfy { $0.finger != nil }, name)
                    XCTAssertEqual(song.notes.map(\.id), Array(song.notes.indices), name)
                    let bars = section.barCount
                    XCTAssertEqual(song.barStartBeats.count, bars, name)
                    XCTAssertEqual(song.notes.first { $0.hand == .left }?.startBeat, 0, name)
                    // Nothing runs past the piece.
                    for note in song.notes {
                        XCTAssertLessThanOrEqual(note.startBeat + note.durationBeats, Double(bars) * 3 + 1e-9, name)
                    }
                }
            }
        }
    }

    func testSectionsAreCutAtScoreBars() {
        // Section 1 is score bars 3–10: it starts with the pickup (first note on beat 2), shifted to the start.
        let first = Piece.song(.first, from: source)
        let right = first.notes.filter { $0.hand == .right }
        XCTAssertEqual(right.first?.startBeat, 1)
        XCTAssertEqual(right.first?.pitch, 64)
        XCTAssertEqual(right.first?.finger, 3)
        XCTAssertEqual(right.count, 2 + 3 * 3 + 2 + 3 * 3)
        XCTAssertEqual(first.notes.filter { $0.hand == .left }.count, 8 * 5)
        // The whole song is score bars 3–116, everything after the intro.
        let whole = Piece.song(.whole, from: source)
        XCTAssertEqual(whole.notes.count, source.notes.filter { $0.startBeat >= 6 }.count)
        // Parts add up.
        XCTAssertEqual(Piece.song(.verse, from: source).notes.count,
                       [Piece.Section.first, .second, .third].map { Piece.song($0, from: source).notes.count }.reduce(0, +))
    }

    func testTiesAndTheLastBars() {
        // The tied note in bars 64–65 is one note of five beats.
        let gPos = Piece.song(.gPosition, from: source).notes.filter { $0.hand == .right }
        let tied = gPos.first { $0.startBeat == 10 }!
        XCTAssertEqual(tied.durationBeats, 5 * 0.95, accuracy: 1e-9)
        XCTAssertFalse(gPos.contains { $0.startBeat >= 12 && $0.startBeat < 15 }, "nothing new in bar 65")
        // The ending: the last right-hand note is held to the end, over a low note for the last two bars.
        let ending = Piece.song(.ending, from: source)
        let lastRight = ending.notes.filter { $0.hand == .right }.last!
        XCTAssertEqual(lastRight.startBeat + lastRight.durationBeats / 0.95, 30, accuracy: 1e-9)
        let lastLeft = ending.notes.filter { $0.hand == .left }.last!
        XCTAssertEqual(lastLeft.startBeat, 24)
        XCTAssertEqual(lastLeft.durationBeats, 6 * 0.95, accuracy: 1e-9)
    }

    func testEasierHands() {
        // Low notes: one per bar, the downbeat's lowest, held the whole bar.
        let roots = Piece.song(.second, from: source, left: .root).notes.filter { $0.hand == .left }
        XCTAssertEqual(roots.count, 8)
        XCTAssertTrue(roots.allSatisfy { $0.durationBeats == 3 * 0.95 && $0.finger == 5 })
        XCTAssertEqual(roots.map(\.startBeat), (0..<8).map { Double($0) * 3 })
        // Low note + chord: the downbeat, then the chord on 2 held through 3.
        let oomPah = Piece.song(.first, from: source, left: .rootAndChord).notes.filter { $0.hand == .left }
        XCTAssertEqual(oomPah.count, 8 * 3)
        XCTAssertEqual(oomPah.filter { $0.startBeat == 1 }.map(\.durationBeats), [2 * 0.95, 2 * 0.95])
        XCTAssertFalse(oomPah.contains { $0.startBeat == 2 })
        // The last two bars keep their one held low note.
        let endRoots = Piece.song(.ending, from: source, left: .root).notes.filter { $0.hand == .left }
        XCTAssertEqual(endRoots.last?.durationBeats ?? 0, 6 * 0.95, accuracy: 1e-9)
        // Long notes: the first note of each bar, held to the end of the bar.
        let simple = Piece.song(.first, from: source, right: .firstNotes).notes.filter { $0.hand == .right }
        XCTAssertEqual(simple.count, 8, "one held note per bar")
        XCTAssertEqual(simple[0].startBeat, 1, "the pickup bar's first note is on beat 2")
        XCTAssertEqual(simple[0].durationBeats, 2 * 0.95, accuracy: 1e-9)
        XCTAssertEqual(simple[1].durationBeats, 3 * 0.95, accuracy: 1e-9)
    }

    func testRoundTripsThroughMIDI() throws {
        let song = Piece.song(.verse, from: source)
        let parsed = try MIDIFileParser.parse(MIDIFileWriter.write(song))
        XCTAssertEqual(parsed.notes.map(\.pitch), song.notes.map(\.pitch))
        XCTAssertEqual(parsed.notes.map(\.finger), song.notes.map(\.finger))
        XCTAssertEqual(parsed.timeSignatures.first?.numerator, 3)
        // A file written from the whole song (bars 1–116) passes the check.
        XCTAssertNil(Piece.problem(with: try MIDIFileParser.parse(MIDIFileWriter.write(source))))
    }
}

final class GreensleevesPieceTests: XCTestCase {
    typealias Piece = GreensleevesPiece

    func testSectionsAreWholeBarsOf3_4WithFingers() {
        for section in Piece.Section.allCases {
            for right in [Piece.Right.melody, .even] {
                for left in [Piece.Left.root, .full] {
                    let song = Piece.song(section, right: right, left: left)
                    let name = song.title
                    XCTAssertEqual(song.timeSignatures.first?.numerator, 3, name)
                    XCTAssertEqual(song.tempoMap[0].bpm, 72, accuracy: 0.01, name)
                    XCTAssertTrue(song.notes.allSatisfy { $0.finger != nil }, name)
                    XCTAssertEqual(song.notes.map(\.id), Array(song.notes.indices), name)
                    XCTAssertEqual(song.barStartBeats.count, section.barCount, name)
                    for note in song.notes {
                        let barEnd = (floor(note.startBeat / 3) + 1) * 3
                        XCTAssertLessThanOrEqual(note.startBeat + note.durationBeats, barEnd + 1e-9, name)
                    }
                    if right == .even {
                        let offsets = song.notes.filter { $0.hand == .right }.map { $0.startBeat.truncatingRemainder(dividingBy: 1) }
                        XCTAssertTrue(offsets.allSatisfy { $0 == 0 }, "every note on a beat: \(name)")
                    }
                }
            }
        }
    }

    /// The whole song matches the user's file (bar by bar, from `Greensleeves (simple).mid`).
    func testWholeSongMatchesTheFile() {
        let song = Piece.song(.whole)
        let right = song.notes.filter { $0.hand == .right }
        let left = song.notes.filter { $0.hand == .left }
        XCTAssertEqual(right.count, 70)
        XCTAssertEqual(left.count, 60)
        XCTAssertEqual(right.prefix(9).map { NoteName.of($0.pitch) },
                       ["A4", "C5", "D5", "E5", "F5", "E5", "D5", "B4", "G4"])
        XCTAssertEqual(right.prefix(9).map(\.finger), [1, 2, 3, 4, 5, 4, 3, 2, 1])
        XCTAssertEqual(right[0].startBeat, 2, "pickup on beat 3")
        XCTAssertEqual(right[4].startBeat, 7.5, "the short note on \"and\" of 2 in bar 3")
        // Bar 17: the leap to G5 with finger 5.
        let bar17 = right.first { $0.startBeat == 48 }!
        XCTAssertEqual(NoteName.of(bar17.pitch), "G5")
        XCTAssertEqual(bar17.finger, 5)
        XCTAssertEqual(left.prefix(4).map { NoteName.of($0.pitch) }, ["A2", "E3", "C3", "G3"])
        XCTAssertEqual(left.prefix(2).map(\.startBeat), [3, 5])
        XCTAssertEqual(left.suffix(2).map(\.startBeat), [90, 90], "last bar: the fifth held together")
    }

    func testEasierVersions() {
        let first = Piece.song(.first)
        let lastRight = first.notes.filter { $0.hand == .right }.last!
        XCTAssertEqual(NoteName.of(lastRight.pitch), "E4", "phrase 1 ends on E, without the next pickup")
        XCTAssertEqual(lastRight.durationBeats, 3 * 0.95, accuracy: 1e-9)
        XCTAssertEqual(Piece.song(.first, right: .even).notes.filter { $0.hand == .right }.count,
                       first.notes.filter { $0.hand == .right }.count, "same notes, other rhythm")
        let roots = Piece.song(.refrain, left: .root).notes.filter { $0.hand == .left }
        XCTAssertEqual(roots.count, 16, "one low note per bar")
        XCTAssertTrue(roots.allSatisfy { $0.finger == 5 })
        let parsed = try! MIDIFileParser.parse(MIDIFileWriter.write(Piece.song(.whole)))
        XCTAssertEqual(parsed.notes.map(\.pitch), Piece.song(.whole).notes.map(\.pitch))
        XCTAssertEqual(parsed.notes.map(\.finger), Piece.song(.whole).notes.map(\.finger))
    }
}

final class GuidedPathTests: XCTestCase {
    let path = TwoHandsPath.entry.path(with: FakeSetaregaan.song)!

    func testPathContent() {
        XCTAssertEqual(path.lessons.count, 10)
        XCTAssertEqual(GreensleevesPath.path.lessons.count, 9)
        let entries = GuidedPath.entries
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count, "unique path ids")
        let paths = entries.map { $0.path(with: FakeSetaregaan.song)! }
        XCTAssertEqual(paths.map(\.id), entries.map(\.id))
        XCTAssertEqual(paths[1].lessons.count, 12, "Setaregan: Second Half")
        for path in paths { check(path) }
        // A path built from a file needs the file, and the right one.
        XCTAssertNil(TwoHandsPath.entry.path(with: nil))
        XCTAssertNil(TwoHandsPath.entry.path(with: FakeSetaregaan.make(bars: 40)))
        XCTAssertNotNil(TwoHandsPath.entry.songFile)
        XCTAssertNil(entries[2].songFile, "Greensleeves is built in")
        XCTAssertNotNil(entries[2].path(with: nil))
        XCTAssertEqual(path.step(after: path.steps[2])?.id, "2.1")
        XCTAssertNil(path.step(after: path.steps.last!))
        XCTAssertEqual(path.lesson(of: path.steps[3])?.number, 2)
    }

    private func check(_ path: GuidedPath) {
        XCTAssertEqual(path.lessons.map(\.number), Array(1...path.lessons.count))
        let ids = path.steps.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "unique step ids")
        for lesson in path.lessons {
            XCTAssertFalse(lesson.goal.isEmpty)
            XCTAssertFalse(lesson.steps.isEmpty, lesson.title)
        }
        for step in path.steps {
            XCTAssertFalse(step.instruction.isEmpty, step.id)
            XCTAssertGreaterThanOrEqual(step.runs, 1, step.id)
            XCTAssertFalse(PracticeSteps.make(from: step.song.notes, clef: step.hand).isEmpty, step.id)
            if step.mode == .playAlong { XCTAssertNotNil(step.hand, "play along needs a hand: \(step.id)") }
            if step.mode == .listen { XCTAssertNil(step.hand, "listen plays both hands: \(step.id)") }
        }
        // Within a lesson, timed steps of one piece and hand never get slower.
        for lesson in path.lessons {
            var last: [String: Double] = [:]
            for step in lesson.steps where step.mode == .timed {
                let key = step.song.title + "\(String(describing: step.hand))"
                XCTAssertGreaterThanOrEqual(step.speed, last[key] ?? 0, step.id)
                last[key] = step.speed
            }
        }
    }

    private func run(_ step: PathStep, mistakes: Int = 0, speed: Double? = nil, hand: Clef?? = nil) -> PathStep.Run {
        let timed = step.mode == .timed || step.mode == .playAlong
        let result = step.mode == .listen ? nil : PracticeResult(timed: timed, total: 100, wrong: mistakes)
        return PathStep.Run(mode: step.mode, hand: hand ?? step.hand, speed: speed ?? step.speed, result: result)
    }

    func testVerdicts() {
        let timed = path.steps.first { $0.mode == .timed && $0.speed < 1 }!
        XCTAssertEqual(timed.verdict(run(timed)), .good)
        XCTAssertEqual(timed.verdict(run(timed, mistakes: 10)), .good, "10% is still a pass")
        XCTAssertEqual(timed.verdict(run(timed, mistakes: 11)), .tooManyMistakes)
        XCTAssertEqual(timed.verdict(run(timed, speed: timed.speed - 0.05)), .notThisStep, "slower doesn't count")
        XCTAssertEqual(timed.verdict(run(timed, speed: timed.speed + 0.05)), .good, "faster does")
        XCTAssertEqual(timed.verdict(run(timed, hand: .some(nil))), .notThisStep, "other hand")
        var skipped = run(timed)
        skipped.skippedAhead = true
        XCTAssertEqual(timed.verdict(skipped), .notThisStep)
        var asWait = run(timed)
        asWait.mode = .wait
        XCTAssertEqual(timed.verdict(asWait), .notThisStep)
        let wait = path.steps.first { $0.mode == .wait }!
        XCTAssertEqual(wait.verdict(run(wait, speed: 0.3)), .good, "wait mode has no speed")
        let listen = path.steps[0]
        XCTAssertEqual(listen.mode, .listen)
        XCTAssertEqual(listen.verdict(run(listen)), .good)
        XCTAssertEqual(listen.verdict(run(listen, speed: 0.5)), .notThisStep)
    }

    func testStepsOpenInOrderAndRunsAreInARow() {
        var progress = PathProgress()
        let steps = path.steps
        XCTAssertEqual(progress.current(in: path)?.id, "1.1")
        XCTAssertTrue(progress.isOpen(steps[0], in: path))
        XCTAssertFalse(progress.isOpen(steps[1], in: path))
        XCTAssertEqual(progress.record(run(steps[1]), of: steps[1], in: path), .notCounted, "locked")

        XCTAssertEqual(progress.record(run(steps[0]), of: steps[0], in: path), .passed)
        XCTAssertEqual(progress.record(run(steps[1]), of: steps[1], in: path), .passed)
        XCTAssertEqual(progress.record(run(steps[2]), of: steps[2], in: path), .passed)

        let twice = steps[3]
        XCTAssertEqual(twice.runs, 2)
        XCTAssertEqual(progress.record(run(twice), of: twice, in: path), .counted(streak: 1, runs: 2))
        XCTAssertEqual(progress.streak(of: twice), 1)
        XCTAssertEqual(progress.record(run(twice, mistakes: 50), of: twice, in: path), .startAgain(runs: 2))
        XCTAssertEqual(progress.streak(of: twice), 0)
        XCTAssertEqual(progress.record(run(twice, speed: 0.3), of: twice, in: path), .notCounted)
        XCTAssertEqual(progress.record(run(twice), of: twice, in: path), .counted(streak: 1, runs: 2))
        XCTAssertEqual(progress.record(run(twice), of: twice, in: path), .passed)
        XCTAssertEqual(progress.streak(of: twice), 2)
        XCTAssertEqual(progress.passedCount(in: path), 4)
        XCTAssertEqual(progress.current(in: path)?.id, "2.2")

        // Replaying a passed step changes nothing, even with mistakes.
        XCTAssertEqual(progress.record(run(steps[1], mistakes: 50), of: steps[1], in: path), .notCounted)
        XCTAssertTrue(progress.isPassed(steps[1]))

        let saved = try! JSONDecoder().decode(PathProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(saved, progress)
    }
}
