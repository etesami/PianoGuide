import Foundation

/// "Greensleeves: Moving Hand": a path on the user's "Greensleeves (simple)". Here the hands fit together easily
/// (the left hand plays on beats 1 and 3, mostly with the right hand); the work is in the right hand, which changes
/// position about eight times while the dotted rhythm lilts. The ideas, in order:
/// 1. Know each hand alone. 2. Make the left hand's one shape automatic. 3. Learn the right-hand notes and hand moves
/// with the dots taken out. 4. Add the lilt, hearing the left hand (play along). 5. Hands together with the left hand on
/// long notes, then the real left hand. 6. Phrase 1 first, then the verse, the refrain and the whole song.
public enum GreensleevesPath {
    public static let path = GuidedPath(
        id: "moving-hand-greensleeves",
        title: "Greensleeves: Moving Hand",
        summary: """
            For a melody where the hand keeps moving. In Greensleeves the left hand is easy: one shape in four places. \
            The right hand moves to a new position about eight times and has a lilting, dotted rhythm. Nine short \
            lessons: first the notes and moves without the dots, then the lilt, then the hands together, phrase by \
            phrase. Each step opens when the one before is passed. Short sessions work best: 15–20 minutes, then stop.
            """,
        lessons: lessons)

    private typealias Piece = GreensleevesPiece

    private static var lessons: [PathLesson] {
        let first = Piece.song(.first)
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

        lesson("Meet the song",
               goal: "Hear the whole tune once, then know what each hand plays in the first phrase (bars 1–9).",
               tips: ["3/4: count 1-2-3. The song starts with one A on beat 3 (a pickup).",
                      "The left hand plays a low note with 5 on 1 and holds it, then the note five keys up with 1 on 3.",
                      "Right hand: the finger numbers on the staff are the ones to use; they show where the hand moves."],
               [("Listen", "Press Listen and count \"1-2-3\" with the music. Hum the tune if you know it.",
                 Piece.song(.whole), .listen, nil, 1, 1),
                ("Right hand alone", "Wait mode, right hand: the song waits for each note. Follow the finger numbers.",
                 first, .wait, .treble, 1, 1),
                ("Left hand alone", "Wait mode, left hand: low note with 5, then the fifth above with 1. The shape stays; "
                 + "only the place changes (A, C, G, E).", first, .wait, .bass, 1, 1)])

        lesson("Left hand on autopilot",
               goal: "The left hand keeps one shape and moves it between A, C, G and E without looking, so your eyes "
                   + "and attention are free for the right hand.",
               tips: ["Keep fingers 5 and 1 spread the same distance all the time; move the whole hand as one.",
                      "Move during beat 3: as soon as 1 has played the fifth, the hand travels to the next low note.",
                      "In timed mode, don't stop after a slip: catch the next 1."],
               [("Slow and steady", "Press Play. One bar of clicks, then the music moves by itself.",
                 first, .timed, .bass, 0.6, 2),
                ("A bit faster", "The same at 80%. Low note a little stronger than the fifth.",
                 first, .timed, .bass, 0.8, 2),
                ("Full speed, eyes up", "At the song's own speed, eyes on the staff the whole time.",
                 first, .timed, .bass, 1, 2)])

        let even = Piece.song(.first, right: .even)
        lesson("Right-hand notes and moves",
               goal: "The right-hand notes and every hand move, with the dots taken out: each note is one beat, so "
                   + "there is time to think about where the hand goes.",
               tips: ["Bars 1–4: the thumb starts on A, then fingers 2-3-4-5 play C D E F.",
                      "Bar 5: the thumb moves down to G; then G♯ is finger 2 (a black key), A 3, B 4, C 5.",
                      "Bar 9: thumb on E, then thumb again on A, ready for the next phrase.",
                      "Look at the next finger number before the move, not after."],
               [("Notes, no hurry", "Wait mode, right hand. This version has no dotted notes yet.",
                 even, .wait, .treble, 1, 2),
                ("Moves in time", "Press Play, right hand. Move the hand on time, not early or late.",
                 even, .timed, .treble, 0.7, 2)])

        lesson("Add the lilt",
               goal: "The real rhythm: a long note, a short one, then the beat (\"1 – 2-and 3\"). The app plays the "
                   + "left hand so you hear where each 1 falls.",
               tips: ["Count \"ONE – two AND three\": the short note comes on the \"and\" after 2.",
                      "The long note is longer than it looks: hold it until \"and\".",
                      "Same notes and fingers as in lesson 3; only the rhythm changes."],
               [("Lilt, no hurry", "Wait mode, right hand, with the dotted rhythm.", first, .wait, .treble, 1, 1),
                ("With the left hand", "Press Play Along. The app plays the left hand; you play the melody.",
                 first, .playAlong, .treble, 0.7, 2),
                ("Faster", "Play along at 90%.", first, .playAlong, .treble, 0.9, 2)])

        let roots = Piece.song(.first, left: .root)
        lesson("Meet on beat one",
               goal: "Both hands for the first time. The left hand plays only one long note per bar, together with the "
                   + "right hand's note on 1.",
               tips: ["Only beat 1 is together; then the left hand just holds while the right hand moves.",
                      "The left hand moves its low note during the right hand's last note of the bar.",
                      "If it falls apart, drag the staff back and play two bars again and again."],
               [("Together, no hurry", "Wait mode: the song waits until both notes on 1 are down. Press them at the "
                 + "same moment.", roots, .wait, nil, 1, 2),
                ("Slowly in time", "Press Play. Count out loud.", roots, .timed, nil, 0.6, 2),
                ("Faster", "The same at 80%.", roots, .timed, nil, 0.8, 2)])

        lesson("Add the fifth on 3",
               goal: "The real left hand: the fifth comes back on beat 3, together with the right hand's note on 3. "
                   + "The short note on \"and\" is the right hand alone.",
               tips: ["Together on 1, right hand alone on \"2-and\", together on 3.",
                      "The left hand's 1 finger and the right hand's note on 3 go down at the same moment."],
               [("Together, no hurry", "Wait mode, both hands.", first, .wait, nil, 1, 2),
                ("Slowly in time", "Press Play.", first, .timed, nil, 0.6, 2),
                ("Faster", "The same at 80%.", first, .timed, nil, 0.8, 2)])

        let verse = Piece.song(.verse)
        lesson("The whole verse",
               goal: "Bars 1–16: the first phrase twice. The second time ends differently, with F♯ and G♯.",
               tips: ["Bars 14–16 are the new ending: C B A, then G♯ F♯ G♯ and a long A.",
                      "Bar 15: the thumb plays F♯, a black key; finger 2 the G♯ on each side of it.",
                      "In timed mode keep the left hand going after a slip, and let the right hand join on the next 1."],
               [("Together, no hurry", "Wait mode, both hands.", verse, .wait, nil, 1, 2),
                ("Slowly in time", "Press Play.", verse, .timed, nil, 0.6, 2),
                ("Faster", "The same at 80%.", verse, .timed, nil, 0.8, 2),
                ("Full speed", "The song's own speed.", verse, .timed, nil, 1, 2)])

        let refrain = Piece.song(.refrain)
        lesson("The refrain: the leap",
               goal: "Bars 16–31: the melody jumps up to the high G and comes back down, twice. "
                   + "The leaps are the new thing; the rest is music you already know.",
               tips: ["Leap up: during the long A (3 beats) move the whole hand up, so finger 5 lands on the high G.",
                      "From that G the hand sits G 5, F♯ 4, E 3, D 2, B 1; then the thumb moves down to G as in the verse.",
                      "The second leap starts from the long low E with the thumb: the biggest jump. Go on beat 3.",
                      "The left hand plays G three bars in a row: an easy moment, keep your eyes on the right hand."],
               [("Right hand alone", "Wait mode, right hand.", refrain, .wait, .treble, 1, 1),
                ("Leaps in time", "Press Play, right hand.", refrain, .timed, .treble, 0.7, 2),
                ("Left hand alone", "In time, left hand.", refrain, .timed, .bass, 0.8, 1),
                ("Low notes only", "Wait mode, both hands, with the left hand on long notes.",
                 Piece.song(.refrain, left: .root), .wait, nil, 1, 1),
                ("Together, no hurry", "Wait mode, both hands.", refrain, .wait, nil, 1, 2),
                ("Slowly in time", "Press Play.", refrain, .timed, nil, 0.6, 2),
                ("Faster", "The same at 80%.", refrain, .timed, nil, 0.8, 2)])

        let whole = Piece.song(.whole)
        lesson("The whole song",
               goal: "All 31 bars in one go, up to the song's own speed.",
               tips: ["The join from verse to refrain (bars 16–17) is where it breaks: drag back and play across it a few times.",
                      "Let it sing: the long notes are where the tune breathes."],
               [("Together, no hurry", "Wait mode, both hands.", whole, .wait, nil, 1, 1),
                ("Slowly in time", "Press Play.", whole, .timed, nil, 0.6, 2),
                ("80%", "Press Play.", whole, .timed, nil, 0.8, 2),
                ("90%", "Press Play.", whole, .timed, nil, 0.9, 2),
                ("Full speed", "The song's own speed. Well done for getting here!", whole, .timed, nil, 1, 2)])
        return lessons
    }
}
