#!/bin/sh
# Rebuilds the piano guide from its sources:
#   piano-fundamentals.md   the text (edit this)
#   tools/drills.py         the practice drills (bars, finger numbers, lesson notes)
#   tools/figures.py        every figure (keyboards, staves, drill sheet music)
# Outputs:
#   figures/*.svg                                 the figures
#   Piano Fundamentals.pdf                        the guide (iPad Air page size)
#   App/Resources/SampleSongs/Reading Guide/      the drills as .mid + lesson .md (bundled in the app)
# Needs: python3 (figures, MIDI) and the markdown-to-pdf skill with ~/venvs/llm (PDF).
set -e
cd "$(dirname "$0")"
rm -f figures/*.svg
python3 tools/figures.py figures
python3 tools/make_midi.py "../../App/Resources/SampleSongs/Reading Guide"
~/.claude/skills/markdown-to-pdf/scripts/run.sh piano-fundamentals.md -o "Piano Fundamentals.pdf" \
  --page ipad-air --break-before h2 --cover --accent "#1f4fa8" --strong-color "#1f4fa8"
