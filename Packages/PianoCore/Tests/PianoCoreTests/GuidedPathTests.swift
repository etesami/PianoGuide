import XCTest
@testable import PianoCore

final class SetaregaanPieceTests: XCTestCase {
    func testSectionsAreWholeBarsOf3_4WithFingers() {
        for section in SetaregaanPiece.Section.allCases {
            for left in [SetaregaanPiece.Left.root, .rootAndChord, .full] {
                for right in [SetaregaanPiece.Right.melody, .firstNotes] {
                    let song = SetaregaanPiece.song(section, left: left, right: right)
                    let name = song.title
                    XCTAssertEqual(song.timeSignatures.first?.numerator, 3, name)
                    XCTAssertEqual(song.tempoMap[0].bpm, 100, accuracy: 0.01, name)
                    XCTAssertTrue(song.notes.allSatisfy { $0.finger != nil }, name)
                    XCTAssertEqual(song.notes.map(\.id), Array(song.notes.indices), name)
                    let bars = section.barCount
                    XCTAssertEqual(song.barStartBeats.count, bars, name)
                    // The left hand starts every bar.
                    let leftStarts = Set(song.notes.filter { $0.hand == .left }.map(\.startBeat))
                    for bar in 0..<bars { XCTAssertTrue(leftStarts.contains(Double(bar) * 3), "\(name) bar \(bar + 1)") }
                    // No note runs past its bar.
                    for note in song.notes {
                        let barEnd = (floor(note.startBeat / 3) + 1) * 3
                        XCTAssertLessThanOrEqual(note.startBeat + note.durationBeats, barEnd + 1e-9, name)
                    }
                }
            }
        }
    }

    func testFirstSectionNotes() {
        let song = SetaregaanPiece.song(.first)
        let right = song.notes.filter { $0.hand == .right }
        // Pickup E F, then G F, G F, G E, twice.
        XCTAssertEqual(right.prefix(8).map { NoteName.of($0.pitch) }, ["E4", "F4", "G4", "F4", "G4", "F4", "G4", "E4"])
        XCTAssertEqual(right.prefix(8).map(\.finger), [1, 2, 3, 2, 3, 2, 3, 1])
        XCTAssertEqual(right.count, 16)
        // Bar 2 (score bar 4) is an F chord: F3 on 1, A3 + C4 on 2 and 3.
        let bar2 = song.notes.filter { $0.hand == .left && $0.startBeat >= 3 && $0.startBeat < 6 }
        XCTAssertEqual(bar2.map { NoteName.of($0.pitch) }, ["F3", "A3", "C4", "A3", "C4"])
        XCTAssertEqual(PracticeSteps.make(from: song.notes, clef: .bass).count, 24)
    }

    func testEasierHands() {
        let roots = SetaregaanPiece.song(.second, left: .root)
        XCTAssertEqual(roots.notes.filter { $0.hand == .left }.count, 8, "one low note per bar")
        let oomPah = SetaregaanPiece.song(.first, left: .rootAndChord)
        XCTAssertEqual(oomPah.notes.filter { $0.hand == .left }.count, 8 * 3)
        let simple = SetaregaanPiece.song(.first, right: .firstNotes)
        let right = simple.notes.filter { $0.hand == .right }
        XCTAssertEqual(right.count, 8, "one held note per bar")
        XCTAssertEqual(right[0].startBeat, 1, "the pickup bar's first note is on beat 2")
        XCTAssertEqual(right[0].durationBeats, 2 * 0.95, accuracy: 1e-9)
        XCTAssertEqual(right[1].durationBeats, 3 * 0.95, accuracy: 1e-9)
        XCTAssertEqual(SetaregaanPiece.song(.verse).notes.filter { $0.hand == .right }.count,
                       [SetaregaanPiece.Section.first, .second, .third]
                           .map { SetaregaanPiece.song($0).notes.filter { $0.hand == .right }.count }.reduce(0, +))
    }

    func testRoundTripsThroughMIDI() throws {
        let song = SetaregaanPiece.song(.verse)
        let parsed = try MIDIFileParser.parse(MIDIFileWriter.write(song))
        XCTAssertEqual(parsed.notes.map(\.pitch), song.notes.map(\.pitch))
        XCTAssertEqual(parsed.notes.map(\.finger), song.notes.map(\.finger))
        XCTAssertEqual(parsed.timeSignatures.first?.numerator, 3)
    }
}

final class GuidedPathTests: XCTestCase {
    let path = TwoHandsPath.path

    func testPathContent() {
        XCTAssertEqual(path.lessons.count, 10)
        XCTAssertEqual(path.lessons.map(\.number), Array(1...10))
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
        XCTAssertEqual(path.step(after: path.steps[2])?.id, "2.1")
        XCTAssertNil(path.step(after: path.steps.last!))
        XCTAssertEqual(path.lesson(of: path.steps[3])?.number, 2)
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
