# Status & handoff

**Read this first when starting a new session.** Keep it current: update it at the end of every work session.

Last updated: 2026-10-06 (session 7: song library and `.mid` import from the Files app)

## Where we are

Milestones 0–2, 4 and 8 (staff view) are partly done (see the table in [PLAN.md §8](../PLAN.md#8-milestones)).

**Verified:**
- `PianoCore` package: the `Song` model, a Standard MIDI File parser and writer, `PracticeSteps` (groups chords),
  `WaitModeEngine`, and the sample song "Twinkle Twinkle" (`App/Resources/SampleSongs/twinkle.mid`).
  15 XCTest tests pass with `scripts/check-core.sh` (`swift test`); the package is in Swift 6 language mode (session 4).
- **The app builds with Xcode 26.3 (Swift 6.2, iOS 26.2 SDK) and runs in the iPad Pro 11" simulator** (2026-10-06):
  title, connection hint, step strip (C3+C4, C4, G4, …) and the keyboard (C2–C5). Tapping keys can't be done from the command line.
- **FP-30X connected to the Mac by USB-C**: macOS sees it as MIDI source "Roland Digital Piano" (2026-10-06).
- **Mac Catalyst build works** (`SUPPORTS_MACCATALYST: YES` in `project.yml`) and the app launches as a Mac window.
  This is how we test with the real piano on the Intel Mac (see [DEVELOPMENT.md](DEVELOPMENT.md#test-with-the-piano-on-the-mac-mac-catalyst)).
- **Real piano works end to end in the Catalyst app** (2026-10-06, session 4): the header shows
  "Connected: Roland Digital Piano"; playing C3+C4 turned step 1 green and moved to step 2; a wrong D4 counted
  "wrong notes: 1"; then C4 moved to step 3. Window screenshots work (Screen Recording permission granted).
- **Key labels** (session 5): every on-screen key shows its note name (C4, F#4, …); the "Aa" toolbar button
  shows/hides them, and the choice is remembered (`@AppStorage("showKeyLabels")`). Seen in the simulator screenshot.
- **Key colors** (session 5, confirmed by the user on the real piano): a key is green if it was correct when pressed,
  red if wrong, and keeps that color until released (even after the step moves on). After a wrong note, the keys
  still needed for the step turn orange until the step is done. No blue hint on the keyboard. Logic: `WaitModeEngine.keyStates`.
- **Staff view** (session 6, seen in simulator screenshots; not yet tried by the user): the song is drawn on a grand staff
  (treble = right hand, bass = left hand) with clefs, time signature, bar lines, note heads (whole/half/quarter/eighth/16th),
  stems, flags, sharps and ledger lines. A blue cursor sits just before the next notes and the music slides left
  (animated) when a step is done. Colors: played = green, next = blue, still needed after a wrong note = orange,
  held wrong keys = red heads at the cursor. It replaces the old text strip of steps. Layout math is in
  `PianoCore/StaffLayout.swift` (tested); drawing is `App/Sources/StaffView.swift` (a `Canvas`).
  Checked by temporarily auto-playing the first steps through `midi.simulate` (hook removed afterwards).

- **Song library** (session 7): a "Songs" toolbar button (music-list icon) opens a sheet with the bundled samples and
  "My Songs". **Import** opens the Files picker (`.mid`, several at once); each file is checked with the parser, then copied
  into Documents/Songs (a name clash adds " 2"). Picking a single imported file opens it right away. Swipe to delete imported
  songs. The title of an imported song is its file name. The last song is remembered (`@AppStorage("lastSong")`).
  Verified in the simulator: a song copied into Documents/Songs loads on launch with the right title, steps and keyboard range.
  **Not verified:** the sheet and the Files picker themselves (taps can't be done from the command line).
- **Test songs for import** (session 7): `TestSongs/Ode to Joy.mid` (two tracks, left-hand triads, dotted rhythm) and
  `TestSongs/Minuet in G.mid` (single track split at middle C, 3/4, eighths, F#, tempo change); see `TestSongs/README.md`.
  Generated from `PianoCore/TestSongs.swift`; the writer now also writes time signatures and single-track files.
  Both load in the simulator with the right time signature, hands and step count. 16 tests pass.

**Not yet verified:** running on the real iPad; in-app Bluetooth pairing; the Songs sheet and import picker by hand.

## Next steps (in order)

1. User to try the Songs sheet and import the files in `TestSongs/` (or any downloaded `.mid`), and the staff view.
2. Import follow-ups, only if wanted: "Open in…" / AirDrop into the app (document types in `project.yml`), renaming songs,
   more bundled samples.
3. Staff view gaps: rests, beams for eighths, dotted notes, flats/key signatures, neighbouring chord notes (seconds)
   overlap, and the notes are spaced by time (not by engraving rules). Add only what the user asks for.
4. Milestone 3 (piano roll + running clock, play/pause, tempo): **on hold (user's call, 2026-10-06).** Open questions
   when it resumes: horizontal roll vs falling notes (the keyboard strip is at the bottom), whether wait mode uses the
   clock to glide between steps, and no scoring while the clock runs freely (that is milestone 5).
5. Later: switch the app target to Swift 6 (`SWIFT_VERSION` in `project.yml`; core types are already `Sendable`).

**On hold (user's call, 2026-10-06): real-iPad testing.** Don't ask about or plan around it until the user brings it back.
Test in the simulator (on-screen keys) and the Mac Catalyst build (real piano) instead. When it resumes (the Apple ID
and team are already set up): connect the iPad, turn on Developer Mode, install from Xcode
([DEVELOPMENT.md](DEVELOPMENT.md#install-on-ipad)), and pair the FP-30X with the in-app Bluetooth button.

## Decisions log

| Date | Decision |
|---|---|
| 2026-10-06 | iPad only, iPadOS 17+, SwiftUI. Installed from Xcode with a free Apple ID (the app must be re-signed every 7 days). |
| 2026-10-06 | Input: MIDI files first, MusicXML later. |
| 2026-10-06 | Display: **horizontal piano roll** first (user's choice), with the renderer kept swappable. |
| 2026-10-06 | Keyboard: Roland FP-30X with built-in Bluetooth MIDI. |
| 2026-10-06 | XcodeGen `project.yml`; bundle ID `com.esnetsm.pianoguide`. |
| 2026-10-06 | No third-party dependencies for now: our own SMF parser and CoreMIDI used directly (MIDIKit was in the draft plan). |
| 2026-10-06 | Wait mode: every chord note must be held down together; releasing one early un-counts it. |
| 2026-10-06 | Test with the real piano on the Mac via a **Mac Catalyst** build (the iOS simulator can't see the Mac's MIDI devices; "Designed for iPad" needs Apple silicon). |
| 2026-10-06 | Apple ID added; `DEVELOPMENT_TEAM: YC58PFGW9Q` (personal team) is in `project.yml`. Mac Catalyst builds sign to run locally ("-"), so choosing "My Mac" in Xcode works. |
| 2026-10-06 | Core tests use XCTest (`swift test`); `PianoCore` uses swift-tools 6.0 / Swift 6 mode, iOS 17+ / macOS 14+. The old plain-`swiftc` check runner was removed. |
| 2026-10-06 | Key colors: green = correct, red = wrong (decided at press time), orange = needed keys after a mistake; no blue "next key" hint on the keyboard (user's choice). |
| 2026-10-06 | **Staff notation moved ahead of the piano roll** (user asked for sheet-music style like Simply Piano): grand staff that scrolls past a fixed cursor; MIDI notes are rounded to the nearest note value; black keys are spelled as sharps. |
| 2026-10-06 | Hands in MIDI files: 2 or more note tracks means track 1 is the right hand and track 2 the left; a single track is split at middle C (60). |
| 2026-10-06 | **Milestone 3 (piano roll) on hold**; song import done first (user's call). |
| 2026-10-06 | Song library: imported `.mid` files are **copied** into the app (Documents/Songs), so they stay if the original moves; the file name is the song title; the last song opens on launch. No database: the folder is the library. |

## Known issues / caveats

- The dev Mac is an **Intel Mac**. Xcode 26.3 is installed and selected (`xcode-select -p` → Xcode.app). The simulator is slow
  to launch the first time (about 15 s before the UI appears).
- The iPad simulator runs its **own MIDIServer**: it does not see USB/Bluetooth MIDI devices connected to the Mac, and
  network MIDI (`MIDINetworkSession`) isn't available there either (tried; nothing is advertised). Use the on-screen keys
  in the simulator, and the Mac Catalyst build for the real piano.
- On-screen keys **latch chord notes** (a clicked chord key stays held until the chord is complete), because a mouse can
  only hold one key. Added 2026-10-06 after the simulator got stuck on step 1 (C3+C4). Not yet confirmed by the user.
- The FP-30X should be paired through the **in-app** Bluetooth screen, not iOS Settings → Bluetooth.
- The parser doesn't support SMPTE time division or format 2 files; it reports a clear error for both.
