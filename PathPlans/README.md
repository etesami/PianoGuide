# Path plans

A guided path can be written as a **plan file** (`.md`) instead of code. The app builds the path from the plan and the
song's MIDI file, both imported in the app (**Paths → Import Files…**, pick both at once or one after the other).
The song's notes never go into the repo: only the plan does. A path shows once its plan and a fitting song are imported.

The plans here are for the user's own MIDI files (kept outside the repo):

| Plan | Song file |
| --- | --- |
| `Two Hands Together.md` | `Ghoghaye Setaregan.mid` (made by `ghoghaye_setaregan.py`, in Google Drive) |
| `Setaregan Second Half.md` | the same file |

The core tests read every plan here and build it from a made-up song of the same shape, so a broken plan fails
`scripts/check-core.sh`.

## Format

```
# Two Hands Together               title of the path
id: two-hands-setaregan            keep it the same: progress is saved under it
song: Ghoghaye Setaregan           the song's name (default: the file name)
file: Ghoghaye Setaregan.mid       the song file the plan is for
short: Setaregan                   start of every piece's title (default: the song's name)
time: 3/4                          the song's time signature
bars: 116                          the song's length in bars (the file is checked against time and bars)

Summary of the path: one or more paragraphs.

## Parts
Section 1: 3-10                    name: first-last score bar (bar 1 = the file's first bar)
Verse: 3-26

## Lesson: Meet the song           lessons are numbered in order
goal: What the lesson is for.
tip: One tip per line, as many as needed.

### Listen                         a step; steps open in order
piece: Section 1                   a part from "## Parts"
left: low notes                    optional: full (default), low notes, low note + chord
right: long notes                  optional: melody (default), long notes
play: listen 75%                   see below
runs: 2                            good runs in a row to pass (default 1)
What to do: the rest of the lines, shown while the step is open.
```

`play:` is one of

- `listen 75%`: the app plays both hands; passed by listening to the end.
- `wait right` / `wait left` / `wait both` (or just `wait`): the song waits for each note.
- `timed both 80%` (hand optional, default both; speed default 100%): the music moves on by itself.
- `play along right 70%` / `play along left 70%`: the app plays the other hand.

A good run is a green result (mistakes on at most 10% of the notes) played the step's way: same mode and hand, at least
its speed.

Easier versions, made from the song's own notes:

- `left: low notes`: only the lowest note on each downbeat, held at least the whole bar.
- `left: low note + chord`: the downbeat as written, the notes on beat 2 held to the end of the bar, nothing after them.
- `right: long notes`: only the first note in each bar, held to the end of the bar.

The song file needs the right hand on the first track and the left hand on the second (the app's usual MIDI layout);
fingers come from lyric events "1"–"5" just before a note, as in the app's other files.
Mistakes in a plan are reported on import with their line number.
