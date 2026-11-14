"""The practice drills that go with the guide. One source for three outputs: the .mid files, the app's lesson
notes (.md next to each .mid), and the staff pictures in the PDF.

Finger numbers are written only where a hand (re)enters a position (and at thumb-under / cross-over points),
on purpose: the guide teaches reading the rest from the notes themselves.
"""
from __future__ import annotations

FOLDER = 'Reading Guide'     # category folder in App/Resources/SampleSongs

DRILLS = [
    dict(
        file='1 · Landmarks (right hand)', tempo=72, time=(4, 4),
        right=[
            'C4/1:2 D4 E4',
            'D4 E4 C4:2',
            'G4/1:2 A4 B4',
            'A4 B4 G4:2',
            'C4/1 E4 G4:2',
            'G4/1 B4 D5 C5',
            'B4 A4 G4:2',
            'C4/1:4',
        ],
        note="""# Landmarks: Middle C and Treble G

Two notes to know on sight: **Middle C** (on its own short line under the treble staff) and **Treble G**
(the line the treble clef curls around). Every other note here is a step or two away from one of them.

```staff
right: C4/1! D4 E4 C4 G4/1! A4 B4 G4
caption: Find C or G first (blue). The next notes are steps up: next finger, next key.
```

## Pay attention to
- A finger number only appears when the hand **moves to a new place**. After that, read the notes: a step up is the next finger.
- In bar 5, G is played with finger 5 from C position. In bar 6 the **thumb** moves onto G.
- Bar 8 jumps back to Middle C: look at the note, not at the finger number.
""",
    ),
    dict(
        file='2 · Landmarks (left hand)', tempo=72, time=(4, 4),
        left=[
            'C3/5:2 D3 E3',
            'D3 E3 C3:2',
            'C3/5 E3 G3:2',
            'F3 E3 F3:2',
            'G2/5:2 A2 B2',
            'C3 D3 B2:2',
            'C3/5 D3 E3 F3',
            'G3:2 C3:2',
        ],
        note="""# Landmarks: Bass C, Bass F and Bass G

Three notes to know on sight in the bass staff: **Bass C** (the second space from the bottom), **Bass F**
(the line between the two dots of the bass clef) and **Bass G** (the bottom line).

```staff
left: C3/5! E3 G3:2 F3! E3 F3:2
caption: Bass C with finger 5, and Bass F (blue) with finger 2 in the same position.
```

## Pay attention to
- Left-hand fingers count **the other way**: 5 is the lowest note, 1 (thumb) the highest.
- In bar 5 the hand moves down: finger 5 goes to **Bass G** on the bottom line, the thumb sits on D.
- Bar 7 comes back to C position: look for Bass C, not for the finger number.
""",
    ),
    dict(
        file='3 · Steps and skips (right hand)', tempo=76, time=(4, 4),
        right=[
            'C4/1 D4 E4 F4',
            'G4:2 E4:2',
            'C4 E4 G4 E4',
            'D4 F4 E4:2',
            'C4 F4 D4 G4',
            'E4 C4 D4:2',
            'C4 G4 E4 D4',
            'C4:4',
        ],
        note="""# Steps and skips

Read **the distance**, not the name. A **step** goes from a line to the next space (next key, next finger).
A **skip** goes from a line to the next line (skip one key, skip one finger).

```staff
right: C4/1 D4 E4 F4 C4 E4! G4! E4!
caption: Steps (line, space, line...) then skips (line to line, blue).
```

## Pay attention to
- Only the first note has a finger number. In C position, finger = C 1, D 2, E 3, F 4, G 5.
- Before each bar, look at the **shape**: going up or down? steps or skips?
""",
    ),
    dict(
        file='4 · Steps and skips (left hand)', tempo=76, time=(4, 4),
        left=[
            'C3/5 D3 E3 F3',
            'G3:2 E3:2',
            'C3 E3 G3 E3',
            'D3 F3 E3:2',
            'G3 F3 E3 D3',
            'C3 E3 D3:2',
            'G3 C3 E3 D3',
            'C3:4',
        ],
        note="""# Steps and skips (left hand)

The same reading in the bass staff. In C position the left hand plays C 5, D 4, E 3, F 2, G 1.

```staff
left: C3/5 E3! G3! E3! D3 F3 E3:2
caption: Skips: line to line, every other finger (5, 3, 1).
```

## Pay attention to
- A step up in the left hand is the **next smaller** finger number (5 to 4), a skip jumps one (5 to 3).
- Bar 7 jumps a fifth: from G (thumb) straight down to C (finger 5). The hand doesn't move.
""",
    ),
    dict(
        file='5 · Moving between C and G (right hand)', tempo=72, time=(4, 4),
        right=[
            'C4/1 D4 E4 C4',
            'E4 F4 G4:2',
            'G4 F4 E4 D4',
            'C4:4',
            'G4/1 A4 B4 G4',
            'B4 C5 D5:2',
            'D5 C5 B4 A4',
            'G4:4',
            'C4/1 E4 G4:2',
            'G4/1 B4 D5:2',
            'C4/1 E4 G4:2',
            'C4:4',
        ],
        note="""# Moving between C and G

The hand keeps its five-finger shape and **moves as one piece**. The moves happen during long notes: while you
hold the whole note, look at the next bar and find the new thumb note.

```staff
right: C4:4 G4/1! A4 B4 G4
caption: Hold the whole note C, then lift the hand: the thumb lands on Treble G (blue).
```

## Pay attention to
- Bars 9 to 11 move every bar, with only a half note to get ready. Go slowly (wait mode) until the move is calm.
- In G position: G 1, A 2, B 3, C 4, D 5.
""",
    ),
    dict(
        file='6 · Positions C, G, F (both hands)', tempo=66, time=(4, 4),
        right=[
            'C4/1 D4 E4 F4', 'G4:2 E4:2', 'F4 E4 D4 E4', 'C4:4',
            'G4/1 A4 B4 C5', 'D5:2 B4:2', 'C5 B4 A4 B4', 'G4:4',
            'F4/1 G4 A4 G4', 'A4 C5:2 A4', 'G4 F4 G4 A4', 'F4:4',
            'C4/1 E4 G4 E4', 'D4 F4 E4 D4', 'G4 F4 E4 D4', 'C4:4',
        ],
        left=[
            'C3/5:4', 'E3:4', 'G3:4', 'C3:4',
            'G2/5:4', 'B2:4', 'D3:4', 'G2:4',
            'F2/5:4', 'A2:4', 'C3:4', 'F2:4',
            'C3/5:4', 'F3:4', 'G3:4', 'C3:4',
        ],
        note="""# Positions C, G and F with both hands

Both hands move to a new position every 4 bars. The left hand plays one long note per bar, so you can
**watch the right hand** and still have time to find the new left-hand key.

```staff
right: C4:4 G4/1! A4 B4 C5
left: C3:4 G2/5!:4
caption: Moving from C to G: right thumb to G, left finger 5 to the G at the bottom of the bass staff.
```

## Pay attention to
- Move **both hands at the same time**, during the last whole note of each 4-bar group.
- F position (bars 9 to 12) skips finger 4 in the right hand (that would be B flat, a black key).
- Left hand in G position: G 5, A 4, B 3, C 2, D 1.
""",
    ),
    dict(
        file='7 · Thumb under and cross-over (scales)', tempo=66, time=(4, 4),
        right=[
            'C4/1 D4 E4 F4/1', 'G4 A4 B4 C5', 'B4 A4 G4 F4', 'E4/3 D4 C4:2',
            'r:4', 'r:4', 'r:4', 'r:4',
            'C4/1 D4 E4 F4/1', 'G4 A4 B4 C5', 'B4 A4 G4 F4', 'E4/3 D4 C4:2',
        ],
        left=[
            'r:4', 'r:4', 'r:4', 'r:4',
            'C3/5 D3 E3 F3', 'G3/1 A3/3 B3 C4', 'B3 A3 G3/1 F3', 'E3/3 D3 C3:2',
            'C3/1 B2 A2 G2/1', 'F2 E2 D2 C2', 'D2/4 E2 F2 G2', 'A2/3 B2 C3:2',
        ],
        note="""# Thumb under and cross-over

The C major scale goes past five keys, so the hand **doesn't jump**: the thumb tucks under (going up in the
right hand) or a finger crosses over the thumb (going down). The numbers show only where that happens.

```staff
right: C4/1 D4/2 E4/3 F4/1! G4/2 A4/3 B4/4 C5/5
caption: Right hand going up: 1 2 3, then the thumb passes under to F (blue), 1 2 3 4 5.
```

## Pay attention to
- Right hand up: thumb under on **F**. Right hand down: finger 3 crosses over onto **E**.
- Left hand up: finger 3 crosses over onto **A**. Left hand down: thumb under on **G**.
- Bars 9 to 12 play both hands in **contrary motion**, an octave apart (away from each other and back): the
  crossings happen together. The left hand goes down to **Low C**, two ledger lines under the bass staff.
""",
    ),
    dict(
        file='8 · Reading on your own', tempo=80, time=(4, 4),
        right=[
            'E4/3 D4 C4 D4', 'E4 E4 E4:2', 'D4 D4 D4:2', 'E4 G4 G4:2',
            'E4 D4 C4 D4', 'E4 E4 E4 E4', 'D4 D4 E4 D4', 'C4:4',
        ],
        left=[
            'C3/5:4', 'C3:4', 'G3:4', 'C3:4',
            'C3:4', 'C3:4', 'G3:4', 'C3:4',
        ],
        note="""# Reading on your own

A short tune with **one finger number per hand**. Work out the position from it: the right hand starts on E
with finger 3, so the thumb belongs on C. Then read every note as a step, a skip or a repeat.

```staff
right: E4/3 D4 C4 D4 E4 E4 E4:2
left: C3/5:4 C3:4
caption: Finger 3 on E puts the hand in C position.
```

## Pay attention to
- Say the note names out loud once before playing.
- Then turn finger numbers off on the staff (the 123 button) and play it again.
""",
    ),
]
