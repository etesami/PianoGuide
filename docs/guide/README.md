# Piano guide (PDF + practice drills)

A beginner's guide to reading notes and hand positions, with eight practice drills that are also bundled in the
app (Songs → **Reading Guide**).

| File | What |
|---|---|
| `piano-fundamentals.md` | the guide's text. Figures are `<img src=figures/NAME.svg style=width:NN%>` (no quotes: the PDF step curls quotes) |
| `tools/drills.py` | the drills: bars per hand, finger numbers, tempo, and each drill's lesson note for the app |
| `tools/figures.py` | every figure, one `fig_NAME` function per `figures/NAME.svg`; drill sheet music is `drillK-J.svg` |
| `tools/svgdraw.py`, `tools/music.py` | the small staff/keyboard SVG drawing code and the bar text format |
| `tools/make_midi.py` | writes the drills as `.mid` + `.md` |
| `build.sh` | rebuilds everything |
| `Piano Fundamentals.pdf` | the output (iPad Air page size) |

Rebuild after any change: `docs/guide/build.sh`. It regenerates `figures/`, the PDF, and
`App/Resources/SampleSongs/Reading Guide/` (these drills are not written by `scripts/check-core.sh --write-samples`).
The PDF step uses the `markdown-to-pdf` skill (`~/venvs/llm`, WeasyPrint); figures and MIDI need only `python3`.

Bar text format (drills and figures): `C4/1 D4 E4:2` = C4 with finger 1, D4, E4 for 2 beats; `r` rest, `+` chord,
`!` highlight (blue), `s` empty slot (figures only). Same idea as the app's lesson-note staff blocks.

Notes on the drills:
- Finger numbers only where a hand enters a new position (and at thumb-under / cross-over), on purpose.
- Only sharps on the staff, no dotted notes, no flats: the app's staff can't draw them yet.
- A one-hand drill is a file with one note track, which the app splits at Middle C, so a left-hand-only drill must
  stay below C4.
