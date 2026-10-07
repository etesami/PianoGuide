# PianoGuide

iPad app (SwiftUI) that teaches piano: it loads MIDI files, listens to a Bluetooth MIDI keyboard (Roland FP-30X),
and highlights and scrolls the notes as the user plays.

Start here:
- `docs/STATUS.md`: current progress, next steps, decisions, known issues. **Read first; update at the end of a session.**
- `PLAN.md`: goals, architecture, milestones (update the milestone status column as things finish).
- `docs/DEVELOPMENT.md`: environment, build, test, install on iPad, code map.

Rules:
- The user prefers small steps; don't overbuild ahead of the current milestone.
- Test core logic with `scripts/check-core.sh`; build and run the app as in docs/DEVELOPMENT.md.
- Keep music logic in `Packages/PianoCore` (no UI imports); app code goes in `App/Sources`.
