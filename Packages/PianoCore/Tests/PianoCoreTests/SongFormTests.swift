import XCTest
@testable import PianoCore

final class SongFormTests: XCTestCase {
    /// A 4/4 song from one letter per bar: equal letters are equal bars; "-" is a bar of rests.
    private func song(_ pattern: String) -> Song {
        var notes: [NoteEvent] = []
        for (bar, letter) in pattern.filter({ $0 != " " }).enumerated() where letter != "-" {
            let pitch = UInt8(40 + letter.asciiValue! % 40)
            for beat in 0..<2 {
                notes.append(NoteEvent(id: notes.count, pitch: pitch + UInt8(beat),
                                       startBeat: Double(bar * 4 + beat), durationBeats: 1, velocity: 80))
            }
        }
        return Song(title: "", notes: notes)
    }

    func testWholeStretchTwice() {
        let form = SongForm(song: song("ABCD EFGD ABCD EFGD"))
        XCTAssertEqual(form.summary, "A A")
        XCTAssertEqual(form.sections.map(\.bars), [0..<8, 8..<16])
        XCTAssertEqual(form.barsToLearn, 8)
        XCTAssertEqual(form.sections[0].note, "Comes back at bar 9")
        XCTAssertEqual(form.sections[1].note, "Same as bar 1")
    }

    func testReturnAfterNewMaterial() {
        let form = SongForm(song: song("ABCD EFGD HIJK LMNK ABCD EFGD"))
        XCTAssertEqual(form.summary, "A B A")
        XCTAssertEqual(form.sections.map(\.bars), [0..<8, 8..<16, 16..<24])
        XCTAssertEqual(form.sections[1].note, "Plays once")
        XCTAssertEqual(form.barsToLearn, 16)
    }

    func testNearRepeatMarksTheChangedBar() {
        let form = SongForm(song: song("ABCD ABCE"))
        XCTAssertEqual(form.summary, "A A′")
        XCTAssertEqual(form.sections[1].changedBars, [7])
        XCTAssertEqual(form.sections[1].note, "Like bar 1, but bar 8 is different")
        XCTAssertEqual(form.barsToLearn, 5)
    }

    func testOdeToJoyIsANearRepeat() {
        let form = SongForm(song: TestSongs.odeToJoy)
        XCTAssertEqual(form.summary, "A A′")
    }

    func testAllDifferentHasNoRepeats() {
        let form = SongForm(song: song("ABCD EFGH"))
        XCTAssertFalse(form.hasRepeats)
        XCTAssertEqual(form.summary, "A")
        XCTAssertEqual(form.sections.map(\.bars), [0..<8])
        XCTAssertEqual(form.barsToLearn, 8)
    }

    func testASingleRepeatedBarIsNotASection() {
        XCTAssertFalse(SongForm(song: song("ABCD AEFG")).hasRepeats)
    }

    func testThreeAppearances() {
        let form = SongForm(song: song("AB CD AB EF AB"))
        XCTAssertEqual(form.summary, "A B A C A")
        XCTAssertEqual(form.sections[0].note, "Comes back at bars 5 and 9")
        XCTAssertEqual(form.sections[2].note, "Same as bar 1")
    }

    func testTwoDifferentRepeats() {
        XCTAssertEqual(SongForm(song: song("ABCD ABCD EFGH EFGH")).summary, "A A B B")
    }

    func testRestsAloneDoNotMakeARepeat() {
        XCTAssertFalse(SongForm(song: song("A--B C--D")).hasRepeats)
    }

    func testEverySectionTogetherCoversAllBars() {
        let form = SongForm(song: song("XABCD EABCD FGH ABCD"))
        XCTAssertEqual(form.sections.flatMap { Array($0.bars) }, Array(0..<form.barCount))
    }

    func testEmptySong() {
        let form = SongForm(song: Song(title: "", notes: []))
        XCTAssertEqual(form.sections, [])
        XCTAssertEqual(form.barCount, 0)
    }

    func testTimeSignatureChangeUsesTheRealBars() {
        // Two bars of 3/4 from beat 0, then 4/4: bar 3 starts on beat 6.
        let notes = [0.0, 3, 6, 10].enumerated().map {
            NoteEvent(id: $0.offset, pitch: 60, startBeat: $0.element, durationBeats: 1, velocity: 80)
        }
        let song = Song(title: "", timeSignatures: [TimeSignature(beat: 0, numerator: 3, denominator: 4),
                                                    TimeSignature(beat: 6, numerator: 4, denominator: 4)], notes: notes)
        // All four bars hold one C4 on their first beat, so they are equal.
        let form = SongForm(song: song)
        XCTAssertEqual(form.summary, "A")
        XCTAssertEqual(form.sections[0].note, "One bar played 4 times")
    }

    /// Two hands from two patterns of one letter per bar, as in `song(_:)`; "-" is a bar of rests.
    private func twoHands(right: String, left: String) -> Song {
        func notes(_ pattern: String, hand: Hand, low: UInt8) -> [(Int, UInt8, Hand)] {
            pattern.filter { $0 != " " }.enumerated().compactMap { bar, letter in
                letter == "-" ? nil : (bar, low + letter.asciiValue! % 20, hand)
            }
        }
        let all = (notes(right, hand: .right, low: 60) + notes(left, hand: .left, low: 36)).sorted { ($0.0, $0.1) < ($1.0, $1.1) }
        return Song(title: "", notes: all.enumerated().map {
            NoteEvent(id: $0.offset, pitch: $0.element.1, startBeat: Double($0.element.0 * 4), durationBeats: 4,
                      velocity: 80, hand: $0.element.2)
        })
    }

    func testOneHandIgnoresTheOtherHand() {
        // The left hand repeats while the melody over it changes.
        let song = twoHands(right: "ABCD EFGH", left: "PQRS PQRS")
        XCTAssertFalse(SongForm(song: song).hasRepeats)
        XCTAssertFalse(SongForm(song: song, clef: .treble).hasRepeats)
        let left = SongForm(song: song, clef: .bass)
        XCTAssertEqual(left.summary, "A A")
        XCTAssertEqual(left.sections[1].bars, 4..<8)
        XCTAssertEqual(left.barsToLearn, 4)
    }

    func testOneBarPattern() {
        let form = SongForm(song: twoHands(right: "ABCD EFGH", left: "PPPP QQQQ"), clef: .bass)
        XCTAssertEqual(form.summary, "A B")
        XCTAssertEqual(form.sections[0].bars, 0..<4)
        XCTAssertEqual(form.sections[0].note, "One bar played 4 times")
        XCTAssertEqual(form.barsToLearn, 2)
        XCTAssertTrue(form.hasRepeats)
    }

    func testNearRepeatWinsOverOneBarPatterns() {
        // Three P then something else, twice: that is one phrase coming back, with a new ending.
        XCTAssertEqual(SongForm(song: twoHands(right: "ABCDEFGH", left: "PPPQ PPPR"), clef: .bass).summary, "A A′")
    }

    func testOneBarPatternComingBack() {
        let form = SongForm(song: twoHands(right: "ABCDEFG", left: "PPP Q PPP"), clef: .bass)
        XCTAssertEqual(form.summary, "A B A")
        XCTAssertEqual(form.sections[0].note, "One bar played 3 times, comes back at bar 5")
        XCTAssertEqual(form.sections[2].note, "Same bar as bar 1, played 3 times")
    }

    func testHandWithRestsDoesNotCountThem() {
        // Taking turns: the left hand plays every other bar.
        let form = SongForm(song: twoHands(right: "A-B-C-D-", left: "-P-Q-R-S"), clef: .bass)
        XCTAssertEqual(form.barCount, 8)
        XCTAssertEqual(form.barsToLearn, 4)
    }

    func testRestsBetweenRepeatsAreTheirOwnSection() {
        let form = SongForm(song: twoHands(right: "ABCDEFG", left: "PQ---PQ"), clef: .bass)
        XCTAssertEqual(form.summary, "A – A")
        XCTAssertEqual(form.sections[1].note, "Rests")
        XCTAssertEqual(form.barsToLearn, 2)
    }

    func testHandWithNothingToPlay() {
        let form = SongForm(song: twoHands(right: "ABCD", left: "----"), clef: .bass)
        XCTAssertFalse(form.hasRepeats)
        XCTAssertEqual(form.barsToLearn, 0)
        XCTAssertEqual(form.barCount, 4)
    }
}
