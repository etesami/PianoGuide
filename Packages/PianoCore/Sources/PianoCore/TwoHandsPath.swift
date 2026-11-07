import Foundation

/// "Two Hands Together": a path for a player who is fine with each hand alone but loses track with both,
/// on the verse of Ghoghaye Setaregan. The ideas, in order:
/// 1. Know each hand's part alone. 2. Make the left-hand pattern automatic, so it needs no attention.
/// 3. Hear the two parts together while playing only one (play along). 4. Put the hands together with the left hand
/// cut down to almost nothing, then add back one layer at a time; the right hand is cut down once too.
/// 5. Wait mode first at every layer (no time pressure, it shows what goes together), then timed mode from slow to full speed.
/// 6. Short parts (8 bars) first, then join them.
public enum TwoHandsPath {
    public static let path = GuidedPath(
        id: "two-hands-setaregan",
        title: "Two Hands Together",
        summary: """
            For when each hand plays fine alone but they fall apart together. Ten short lessons on the verse of \
            Ghoghaye Setaregan, a waltz in 3/4: first the left hand learns its pattern until it plays by itself, then \
            the hands meet a little at a time. Each step opens when the one before is passed. Short sessions work \
            best: 15–20 minutes, then stop, even in the middle of a lesson.
            """,
        lessons: lessons)

    private typealias Piece = SetaregaanPiece

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
               goal: "Know what each hand plays in the first 8 bars before putting them together.",
               tips: ["The song is a waltz: count 1-2-3, 1-2-3, with the weight on 1.",
                      "The left hand plays a low note on 1 and a two-note chord on 2 and 3: \"oom-pah-pah\".",
                      "Right-hand thumb on E: E 1, F 2, G 3, A 4."],
               [("Listen", "Press Listen and count \"1-2-3\" out loud with the music. Notice the low note on every 1.",
                 first, .listen, nil, 0.75, 1),
                ("Right hand alone", "Play the melody with the right hand. The song waits for each note.",
                 first, .wait, .treble, 1, 1),
                ("Left hand alone", "Low note with finger 5, then the chord with 3 and 1, twice. For the F chord the whole "
                 + "hand moves up one key.", first, .wait, .bass, 1, 1)])

        lesson("Left hand on autopilot",
               goal: "The left-hand pattern plays itself, so all your attention is free for the right hand. "
                   + "This is the most important lesson: take your time here.",
               tips: ["Count out loud while you play: \"ONE two three\".",
                      "Once the notes are known, look at the screen, not at your hand.",
                      "In timed mode, don't stop after a mistake: keep going and catch the next 1."],
               [("Slow and steady", "Press Play. One bar of clicks, then the music moves by itself.",
                 first, .timed, .bass, 0.6, 2),
                ("A bit faster", "The same at 80%. Keep the chords soft and the low note a little stronger.",
                 first, .timed, .bass, 0.8, 2),
                ("Full speed, eyes up", "At the song's own speed. Keep your eyes on the staff the whole time.",
                 first, .timed, .bass, 1, 2)])

        lesson("Hear the hands together",
               goal: "Feel how the two parts fit, while you still play only one of them.",
               tips: ["Listen for the moments your note and the app's note start together: every beat 1.",
                      "Don't follow the other hand's rhythm: keep your own part steady."],
               [("You play the melody", "Press Play Along. The app plays the left hand; you play the right.",
                 first, .playAlong, .treble, 0.7, 2),
                ("You play the waltz", "Now the app plays the melody and you play the left hand.",
                 first, .playAlong, .bass, 0.7, 2),
                ("Melody, faster", "Play along with the right hand at 90%.", first, .playAlong, .treble, 0.9, 1)])

        let roots = Piece.song(.first, left: .root)
        lesson("Meet on beat one",
               goal: "Both hands for the first time. The left hand plays only one long note per bar, together with the "
                   + "right hand's note on 1.",
               tips: ["Only beat 1 is together. On 2 and 3 the left hand just holds while the right hand moves.",
                      "Bar 1 is a turn: the left hand alone on 1, the right hand alone on 2 and 3.",
                      "If it falls apart, drag the staff back and play just two bars, again and again."],
               [("Together, no hurry", "Wait mode: the song waits until both notes on 1 are down. Press them at "
                 + "the same moment.", roots, .wait, nil, 1, 2),
                ("Slowly in time", "Press Play. Count out loud.", roots, .timed, nil, 0.6, 2),
                ("Faster", "The same at 80%.", roots, .timed, nil, 0.8, 2)])

        let oomPah = Piece.song(.first, left: .rootAndChord)
        lesson("Add the chord",
               goal: "The left hand adds its chord on beat 2 and holds it through 3. Now the hands meet on 1 and on 2.",
               tips: ["Say \"oom-pah\" for the left hand: low note, chord, hold.",
                      "On beat 3 the left hand only holds its chord."],
               [("Left hand warm-up", "The new pattern alone first, in time.", oomPah, .timed, .bass, 0.8, 1),
                ("Together, no hurry", "Wait mode, both hands.", oomPah, .wait, nil, 1, 2),
                ("Slowly in time", "Press Play.", oomPah, .timed, nil, 0.6, 2),
                ("Faster", "The same at 80%.", oomPah, .timed, nil, 0.8, 2)])

        let simpleTop = Piece.song(.first, right: .firstNotes)
        lesson("Full waltz, simple melody",
               goal: "The left hand plays its full waltz while the right hand holds one note per bar. "
                   + "The left hand keeps going by itself; the right hand only drops in.",
               tips: ["The right hand plays the first melody note of each bar and holds it.",
                      "If the left hand stops when the right hand plays, go back to lesson 2 for a few runs."],
               [("Together, no hurry", "Wait mode, both hands.", simpleTop, .wait, nil, 1, 1),
                ("Slowly in time", "Press Play.", simpleTop, .timed, nil, 0.6, 2),
                ("Faster", "The same at 80%.", simpleTop, .timed, nil, 0.8, 2)])

        lesson("Section 1, hands together",
               goal: "The real thing: melody and full waltz, score bars 3–10.",
               tips: ["Wait mode shows exactly which notes go together; look for them before you press.",
                      "In timed mode keep the left hand going after a slip, and let the right hand join again on the next 1.",
                      "Every timed step needs two good runs in a row: a steady hand, not a lucky one."],
               [("Together, no hurry", "Wait mode, both hands.", first, .wait, nil, 1, 2),
                ("Half speed", "Press Play.", first, .timed, nil, 0.5, 2),
                ("A bit faster", "The same at 65%.", first, .timed, nil, 0.65, 2),
                ("Faster again", "The same at 80%.", first, .timed, nil, 0.8, 2)])

        let second = Piece.song(.second)
        lesson("Section 2: the run",
               goal: "Score bars 11–18: the melody climbs to A, then runs down C B A G F over the F chord. "
                   + "The same ladder as before, in fewer steps.",
               tips: ["The A in bar 2 lasts two beats: use them to move the hand up one key, so finger 5 lands on the C in bar 3.",
                      "After the run the thumb slides from F down to E.",
                      "The left hand has a new chord in bar 2: A and C over the low E (fingers 5, 2, 1)."],
               [("Right hand alone", "Wait mode, right hand.", second, .wait, .treble, 1, 1),
                ("Left hand alone", "In time, left hand.", second, .timed, .bass, 0.8, 1),
                ("Low notes only", "Wait mode, both hands, with the left hand on long notes.",
                 Piece.song(.second, left: .root), .wait, nil, 1, 1),
                ("Together, no hurry", "Wait mode, full waltz.", second, .wait, nil, 1, 2),
                ("Slowly in time", "Press Play.", second, .timed, nil, 0.6, 2),
                ("Faster", "The same at 80%.", second, .timed, nil, 0.8, 2)])

        let third = Piece.song(.third)
        lesson("Section 3",
               goal: "Score bars 19–26: the first section's melody with new turns.",
               tips: ["Bar 6 has a rest on beat 3 in the right hand: the left hand plays on alone.",
                      "Bars 3 and 7 end on A (finger 4) over the F chord."],
               [("Low notes only", "Wait mode, both hands, with the left hand on long notes.",
                 Piece.song(.third, left: .root), .wait, nil, 1, 1),
                ("Together, no hurry", "Wait mode, full waltz.", third, .wait, nil, 1, 2),
                ("Slowly in time", "Press Play.", third, .timed, nil, 0.6, 2),
                ("Faster", "The same at 80%.", third, .timed, nil, 0.8, 2)])

        let verse = Piece.song(.verse)
        lesson("The whole verse",
               goal: "Score bars 3–26 in one go, 24 bars, up to the song's own speed.",
               tips: ["The joins between the sections are where it breaks: drag back and play across them a few times.",
                      "Next, import the full song and learn the chorus the same way: hands alone, left hand on autopilot, "
                      + "then together slowly."],
               [("Together, no hurry", "Wait mode, both hands.", verse, .wait, nil, 1, 1),
                ("Slowly in time", "Press Play.", verse, .timed, nil, 0.6, 2),
                ("75%", "Press Play.", verse, .timed, nil, 0.75, 2),
                ("90%", "Press Play.", verse, .timed, nil, 0.9, 2),
                ("Full speed", "The song's own speed. Well done for getting here!", verse, .timed, nil, 1, 2)])
        return lessons
    }
}
