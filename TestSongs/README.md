# Test songs

`.mid` files for trying **Songs → Import** in the app. They are not bundled in the app; copy them to the iPad/simulator
(Files app, AirDrop, or drag onto the simulator window) or pick them from this folder in the Mac Catalyst build.

## For the player

Both are real practice pieces, not just test data. Listed easiest first.

| Song | Level | What you'll practice |
|---|---|---|
| **Ode to Joy** (Beethoven) | Beginner | The right hand stays in one five-finger position (C4–G4, thumb on middle C) the whole time, so you never have to move it. The left hand plays C and G major chords on beats 1 and 3, which is good first practice in pressing three keys together while the other hand keeps going. Watch the dotted rhythm (long–short) at the end of each half. 4/4, 100 BPM, about 40 seconds. |
| **Minuet in G** (Petzold, from the Anna Magdalena Notebook) | Early intermediate | A classic first "real" classical piece. The right hand runs in quick eighth notes, reaches up to G5 with an F# on the way, and jumps back down, so finger crossings and steady eighths are the main work. The left hand plays a slow bass line under it. It slows down near the end (100 → 80 BPM), so keep listening to the tempo. Short (the opening section only), about 15 seconds. |

Suggested path: get Ode to Joy smooth hands together in Wait mode, then try it in Timed mode; then Minuet in G,
hands separately before hands together.

## What each file tests

| File | What it tests |
|---|---|
| `Ode to Joy.mid` | Two tracks (right hand, left hand), 4/4, 100 BPM; three-note left-hand chords (C and G major) on every half bar; dotted quarter + eighth in bars 4 and 8. 30 steps. |
| `Minuet in G.mid` | **One track** (format 0), so the app splits the hands at middle C; 3/4; eighth notes; an F#; a two-note chord (G3+B3); slows from 100 to 80 BPM at bar 7. 33 steps. |

Both are generated from `Packages/PianoCore/Sources/PianoCore/TestSongs.swift`; after changing that file, regenerate
with `scripts/check-core.sh --write-test-songs TestSongs` (a unit test checks the files match).
