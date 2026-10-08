# Test songs

`.mid` files for trying **Songs → Import** in the app. They are not bundled in the app; copy them to the iPad/simulator
(Files app, AirDrop, or drag onto the simulator window) or pick them from this folder in the Mac Catalyst build.

| File | What it tests |
|---|---|
| `Ode to Joy.mid` | Two tracks (right hand, left hand), 4/4, 100 BPM; three-note left-hand chords (C and G major) on every half bar; dotted quarter + eighth in bars 4 and 8. 30 steps. |
| `Minuet in G.mid` | **One track** (format 0), so the app splits the hands at middle C; 3/4; eighth notes; an F#; a two-note chord (G3+B3); slows from 100 to 80 BPM at bar 7. 33 steps. |

Generated from `Packages/PianoCore/Sources/PianoCore/TestSongs.swift`; after changing that file, regenerate with
`scripts/check-core.sh --write-test-songs TestSongs` (a unit test checks the files match).
