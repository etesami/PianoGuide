import Foundation

/// "Setaregan: Second Half": the rest of Ghoghaye Setaregan after the verse (score bars 27–116), for a player who has
/// finished "Two Hands Together". Same recipe (PLAN.md §10): each new part in short pieces, hands alone first, then
/// together with the left hand cut down to its low notes, then the full waltz; wait mode before timed mode, then the
/// speed in small rungs; then the parts joined, and at the end the whole song.
/// New in this half: repeated notes and a dotted turn (chorus), the hand moving up to F, G and A position,
/// a new left-hand chord (G), and long tied notes the right hand holds while the left hand keeps going.
public enum SetaregaanSecondHalfPath {
    /// Built from the imported song file (`SetaregaanPiece.file`).
    public static let entry = PathEntry(
        id: "setaregan-second-half",
        title: "Setaregan: Second Half",
        summary: """
            The rest of Ghoghaye Setaregan after the verse: the chorus, the climb, the high part and the ending \
            (score bars 27–116), learned the same way as "Two Hands Together": each part alone, then the hands \
            meet a little at a time, then the parts are joined. The last lesson is the whole song. Best after \
            finishing "Two Hands Together". Short sessions work best: 15–20 minutes, then stop.
            """,
        songFile: Piece.file,
        build: lessons)

    private typealias Piece = SetaregaanPiece

    @Sendable private static func lessons(_ source: Song) -> [PathLesson] {
        func piece(_ section: Piece.Section, left: Piece.Left = .full, right: Piece.Right = .melody) -> Song {
            Piece.song(section, from: source, left: left, right: right)
        }
        var lessons: [PathLesson] = []
        func lesson(_ title: String, goal: String, tips: [String], _ steps: [(String, String, Song, PathStep.Mode, Clef?, Double, Int)]) {
            let number = lessons.count + 1
            lessons.append(PathLesson(
                id: "\(number)", number: number, title: title, goal: goal, tips: tips,
                steps: steps.enumerated().map { i, s in
                    PathStep(id: "\(number).\(i + 1)", title: s.0, instruction: s.1, song: s.2, mode: s.3,
                             hand: s.4, speed: s.5, runs: s.6)
                }))
        }
        /// The usual ladder for a new part: hands alone, low notes, full waltz in wait mode, then 60% and 80%.
        func newPart(_ section: Piece.Section, right: String, left: String) -> [(String, String, Song, PathStep.Mode, Clef?, Double, Int)] {
            let song = piece(section)
            return [("Right hand alone", right, song, .wait, .treble, 1, 1),
                    ("Left hand alone", left, song, .timed, .bass, 0.8, 1),
                    ("Low notes only", "Wait mode, both hands, with the left hand on long notes.",
                     piece(section, left: .root), .wait, nil, 1, 1),
                    ("Together, no hurry", "Wait mode, full waltz.", song, .wait, nil, 1, 2),
                    ("Slowly in time", "Press Play. Count out loud.", song, .timed, nil, 0.6, 2),
                    ("Faster", "The same at 80%.", song, .timed, nil, 0.8, 2)]
        }

        lesson("Meet the second half",
               goal: "Hear where the song goes after the verse before learning it, part by part.",
               tips: ["Listen for the chorus (repeated notes, from bar 27), the climb up to C, the high part (from bar 79, "
                      + "played twice), and the verse tune coming back at the end.",
                      "Count 1-2-3 with the music: the left hand keeps its waltz almost all the way."],
               [("Listen", "Press Listen and follow the staff. It takes about four minutes.",
                 piece(.secondHalf), .listen, nil, 0.75, 1)])

        lesson("The chorus",
               goal: "Bars 27–34: three quick repeated notes after a rest, stepping down C, B, A, while the left hand "
                   + "starts every bar alone.",
               tips: ["The right hand starts on beat 2: the left hand's low note on 1 is your signal.",
                      "Move the hand up one key (F position: thumb on F, 5 on C) for bars 27–32, then back to thumb on E.",
                      "Repeated notes: let the key come up a little between them; the same finger plays all three.",
                      "Bars 29 and 33 end with a short turn, A-G and G-F: the second note is very short, almost a grace note.",
                      "Left hand: a new chord in bar 1, A and C over the low E (5, 2, 1), as in the verse."],
               newPart(.chorus, right: "Wait mode, right hand. Finger 5 on the first C.",
                       left: "In time, left hand: E minor, A minor, F and E minor chords."))

        lesson("The climb",
               goal: "Bars 35–44: the melody climbs G A B to a long C, then settles on B. The left hand learns a new "
                   + "chord: G.",
               tips: ["After the pickup E F, the hand moves up one key: G with 2, A 3, B 4, C 5.",
                      "The C in bar 5 lasts three beats: keep counting while you hold it.",
                      "New left-hand chord in bars 8–10: G. The hand moves down: D with 5, then G and B with 2 and 1."],
               newPart(.climb, right: "Wait mode, right hand.",
                       left: "In time, left hand. Watch for the new G chord near the end."))

        lesson("Coming down",
               goal: "Bars 45–52: A G F E, twice. Back in the old place, thumb on E.",
               tips: ["Each half starts after a rest, with a little turn A-B-A-G.",
                      "The two halves have the same melody; only the left hand's chords differ a little.",
                      "Bars 4 and 8 end on a long E: rest the hand there."],
               newPart(.comeDown, right: "Wait mode, right hand. Thumb on E, so A is 4 and B is 5.",
                       left: "In time, left hand: mostly the F chord."))

        let verseAgain = piece(.verseAgain)
        lesson("The verse comes back",
               goal: "Bars 53–60: the verse's third section again. You know it: this is a short check before joining.",
               tips: ["If it feels new, go back to \"Two Hands Together\", lesson 9, for a few runs."],
               [("Together, no hurry", "Wait mode, both hands.", verseAgain, .wait, nil, 1, 1),
                ("In time", "Press Play.", verseAgain, .timed, nil, 0.8, 2)])

        let middle = piece(.middle)
        lesson("Bars 27–60 joined",
               goal: "The chorus, the climb, coming down and the verse in one go, 34 bars.",
               tips: ["The joins are where it breaks: drag back two bars before a join and play across it a few times.",
                      "Bar 35: after the long E, the pickup E F takes you into the climb. Bar 45: after the long B, "
                      + "the thumb goes back to E."],
               [("Together, no hurry", "Wait mode, both hands.", middle, .wait, nil, 1, 1),
                ("Slowly in time", "Press Play.", middle, .timed, nil, 0.65, 2),
                ("Faster", "The same at 80%.", middle, .timed, nil, 0.8, 2)])

        lesson("G position",
               goal: "Bars 61–70: the hand moves up to G position (thumb on G, 5 on D), and two long notes are held "
                   + "across the bar line.",
               tips: ["Bar 61 starts straight on A with finger 2: move the hand during the long E before it.",
                      "The A in bars 64–65 and the G in bars 69–70 are tied: hold them for five beats, don't play them again.",
                      "In bar 69 the hand moves back down: thumb on E, G with 3.",
                      "While the right hand holds, the left hand keeps its waltz going."],
               newPart(.gPosition, right: "Wait mode, right hand. Thumb on G.",
                       left: "In time, left hand: E minor and A minor."))

        let longNotes = piece(.longNotes)
        lesson("Long notes",
               goal: "Bars 71–78: the right hand holds long notes, B, G, E, while the left hand plays the E minor waltz "
                   + "all the way.",
               tips: ["Each long note ends with a very short step down just before the next bar: B-A, G-F.",
                      "The E in bars 73–74 (and 77–78) is held for six beats: count two whole bars.",
                      "This is the left hand's autopilot test: it must keep going while the right hand does nothing."],
               [("Together, no hurry", "Wait mode, both hands.", longNotes, .wait, nil, 1, 1),
                ("Slowly in time", "Press Play.", longNotes, .timed, nil, 0.7, 2),
                ("Faster", "The same at 90%.", longNotes, .timed, nil, 0.9, 2)])

        lesson("The high part",
               goal: "Bars 79–92: the highest part of the song, up to E with finger 5. The song plays it twice, so "
                   + "learning it once covers 28 bars.",
               tips: ["Bars 79–82: A position, thumb on A, so C is 3 and the high E is 5.",
                      "Bars 83–86: one key lower, G position: B is 3.",
                      "From bar 87 the thumb is back on E, and the end is much like \"Coming down\": A G, F G F, E.",
                      "Left hand: A minor for the first four bars, then E minor and F."],
               newPart(.high, right: "Wait mode, right hand. Thumb on A, 3 on the first C.",
                       left: "In time, left hand."))

        let ending = piece(.ending)
        lesson("The ending",
               goal: "Bars 107–116: the verse tune one last time, then a long E in both hands.",
               tips: ["The last E is held for eight beats, over a low E in the left hand: let it ring to the end.",
                      "Like the verse: pickup E F, then G F, G A, F E."],
               [("Together, no hurry", "Wait mode, both hands.", ending, .wait, nil, 1, 1),
                ("Slowly in time", "Press Play.", ending, .timed, nil, 0.7, 2),
                ("Faster", "The same at 90%.", ending, .timed, nil, 0.9, 2)])

        let finale = piece(.finale)
        lesson("Bars 61–116 joined",
               goal: "From G position to the end, 56 bars, with the high part twice.",
               tips: ["Bar 79: after the long E, the hand jumps up to A position. Bar 107: after the long E, back to the "
                      + "verse tune.",
                      "Between the two high parts (bar 93) nothing changes: just start it again."],
               [("Together, no hurry", "Wait mode, both hands.", finale, .wait, nil, 1, 1),
                ("Slowly in time", "Press Play.", finale, .timed, nil, 0.65, 2),
                ("Faster", "The same at 80%.", finale, .timed, nil, 0.8, 2)])

        let whole = piece(.whole)
        lesson("The whole song",
               goal: "Ghoghaye Setaregan from the first note to the last, 114 bars, up to its own speed.",
               tips: ["About three and a half minutes at full speed: rest your hands between runs.",
                      "If one part keeps breaking, go back to its lesson for a few runs, then come back.",
                      "Two good runs in a row is a lot for a long song: one run a day is fine."],
               [("Together, no hurry", "Wait mode, both hands.", whole, .wait, nil, 1, 1),
                ("75%", "Press Play.", whole, .timed, nil, 0.75, 2),
                ("90%", "Press Play.", whole, .timed, nil, 0.9, 2),
                ("Full speed", "The song's own speed. Well done for getting here!", whole, .timed, nil, 1, 2)])
        return lessons
    }
}
