# Status & handoff

**Read this first when starting a new session.** Keep it current: update it at the end of every work session.

Last updated: 2026-10-08 (session 12: timed mode with speed, metronome and pause)

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
  Both load in the simulator with the right time signature, hands and step count.
- **Finger numbers** (session 7): notes with a finger show it on the staff, above treble notes and below bass notes
  (clear of stems; stacked for chords), in the note's color. In `.mid` files a finger is stored as a lyric event "1"–"5"
  just before the note-on (our own convention; MIDI has no standard; the writer and parser both handle it).
  New bundled samples for **practising C → F → D → C five-finger positions**: "Positions C-F-D (right hand)" and
  "Positions C-F-D (both hands)" (16 bars each, 4/4, 90 BPM; the first note of each bar in each hand shows its finger).
  F position avoids B♭ because the staff can't show flats yet. Seen in the simulator (bar starts, left-hand 5 under the bass
  staff, both hands together, D position with F#), using a temporary auto-play hook that was removed. 18 tests pass.

- **Song categories** (session 8): bundled samples in a subfolder of `App/Resources/SampleSongs/` belong to that category,
  and the Songs sheet shows each category as a folder row (tap to open its songs) above the loose samples ("twinkle").
  The two C-F-D position songs are now in **Intermediate III** (path set in `SampleSongs.all`, e.g.
  `"Intermediate III/Positions C-F-D (right hand)"`; `write-samples` creates the folder). Verified: 18 tests pass, the
  `.app` contains `SampleSongs/Intermediate III/`, and the last song reopens from that folder in the simulator.
  **Not verified:** tapping the folder in the sheet. Only Intermediate III exists so far; other levels not yet named.

- **Staff zoom by bars** (session 9, user's request): the staff's horizontal scale is no longer fixed; it is set so that,
  from the next note at the cursor, **two whole bars plus the first note of the third bar** fit on screen (uses the
  starting time signature, `TimeSignature.beatsPerBar`). The played-notes area left of the cursor is unchanged. Since the
  music scrolls step by step, this is exact when the cursor is at a bar start; mid-bar, more of the third bar shows.
  Seen in the simulator (Positions C-F-D both hands, 4/4). 18 tests pass.

- **Positions series** (session 9, replaces the two "Positions C-F-D" songs): `PositionPractice.series` in
  `PositionSongs.swift` makes three practices, each adding one position: **1. C position**, **2. C + F positions**,
  **3. C + F + D positions**, each as "(right hand)" and "(both hands)", all in Intermediate III. Each position now
  gets 8 bars (two 4-bar phrases, was 4), and every practice ends with 8 more bars back in C (practice 1 = C twice).
  Lengths: 16 / 24 / 32 bars. Still no B♭ (right-hand 4 and left-hand 2 aren't used in F). 18 tests pass; seen in the
  simulator ("2. C + F positions (both hands)", 72 steps). **Not verified:** playing through the new phrases by hand.

- **Finger coordination drills** (session 9): `FingerPractice` in `FingerSongs.swift`, four bundled songs in
  Intermediate III, each 16 bars in C position (white keys), 4/4, 90 BPM, **finger number on every note**
  (`PositionSongBuilder.fingerEveryNote`): **Fingers 1 · Pairs** (1-2, 2-3, 3-4, 4-5; right hand 8 bars, then left),
  **Fingers 2 · Skips** (1-3, 2-4, 3-5; same layout), **Fingers 3 · Mirror (hands together)** (same finger numbers,
  hands move in opposite directions), **Fingers 4 · Parallel (hands together)** (same note names an octave apart,
  left finger = 6 − right finger). 19 tests pass; "Fingers 4" seen in the simulator (58 steps).
  **Not verified:** playing them by hand.

- **Song progress marks** (session 10, user's request): `SongProgress` in `PianoCore/SongProgress.swift` (tested), kept per
  song by `SongLibrary` in UserDefaults (`songProgress`, JSON keyed by path inside SampleSongs, or "My Songs/<file>").
  A song played to the end gets a **green check** instead of the note icon and "Completed N×". Wrong notes are recorded when
  the song ends, or when it is left early (Restart / another song) with at least one wrong note; with **5 or more** wrong
  notes (`SongProgress.difficultMistakes`) the row is **tinted orange** with a warning triangle and "Difficult · N wrong notes".
  An unfinished attempt can only raise the count, so the mark goes away only by finishing with fewer than 5 mistakes.
  Category folder rows show "x/y completed" and a triangle if a song inside is difficult. The current song's marker is now a
  play icon (was a checkmark, which clashed with "completed"). Deleting an imported song forgets its progress.
  Seen in the simulator with seeded progress and a temporary hook that opened the sheet (removed). 20 tests pass.
  **Not verified:** recording by actually playing a song through; leaving the app mid-song records nothing.

- **User marks** (session 11, user's request): the user can mark a song **Hard** (red flag) or **Interesting**
  (yellow star) to come back to it later. `SongMark` is stored as `SongProgress.mark` (same UserDefaults JSON; older
  saved data without it still loads, tested). Set it by **swiping a song row right**, **long-pressing** it (menu:
  No Mark / Hard / Interesting), or with the **flag button** in the practice toolbar for the open song (the button
  shows the current mark). Marked songs from everywhere (folders and My Songs) are also listed in a **"Marked"** section
  at the top of the Songs sheet. Playing never changes the mark; deleting an imported song forgets it. This is separate
  from the automatic orange "Difficult" (5+ wrong notes). 21 tests pass; seen in the simulator with seeded marks and a
  temporary hook that opened the sheet (removed). **Not verified:** the swipe, long-press menu and flag button by hand.

- **Timed mode** (session 12, user's request): a **Wait | Timed** switch in the middle of the toolbar (remembered,
  `@AppStorage("timedMode")`). In timed mode the song doesn't wait: after **Play** there is one bar of metronome clicks
  (count-in), then the music scrolls continuously past the cursor at the chosen **speed** (stepper, 25–150 % of the song's
  tempo in 5 % steps, shown with the resulting BPM; `@AppStorage("timedSpeed")`, default 75 %). A **metronome** clicks every
  quarter-note beat (higher click on beat 1 of the bar). **Pause** stops the music and clicks; Play resumes where it was
  (no count-in on resume). Each note can be hit within **half a beat** either side of its start; once that window passes,
  unplayed notes turn **orange (missed)**, played ones green; a key that matches no note in its window counts as **wrong**
  (red key, red flash). The header shows "Played X of N · missed Y · wrong Z". Chords don't need to be held together here
  and on-screen keys don't latch. At the end the song is recorded as completed with mistakes = missed + wrong
  (so 5+ gives the "Difficult" mark); stopping early (Restart, other song, switching mode) records them like wait mode.
  Logic: `PianoCore/TimedModeEngine.swift` (tested; also `Song.bpm(atBeat:)` / `beat(after:from:speed:)`); app:
  `TimedSession.swift` (60 Hz clock + engine), `Metronome.swift` (AVAudioEngine, synthesized clicks). 23 tests pass;
  iOS simulator and Mac Catalyst build; seen in simulator screenshots with a temporary auto-play hook (removed): count-in,
  scrolling, missed notes turning orange, wrong notes counted. **Not verified:** hearing the clicks, the buttons by hand,
  playing along with the real piano (timing/latency of the half-beat window).

**Not yet verified:** running on the real iPad; in-app Bluetooth pairing; the Songs sheet and import picker by hand.

## Next steps (in order)

0. User to try timed mode with the real piano (Catalyst build). Open questions: is ±½ beat the right hit window (it gets
   wider in seconds at slow speeds)? Should missed notes be red instead of orange? Count-in on resume after Pause?
   Should a timed run with many misses count as "Completed"? Clicks are fired from a 60 Hz timer (up to ~16 ms jitter);
   schedule them on the audio clock if they sound uneven.
0. User to try marking songs (swipe right, long-press, or the flag button while practising). Open questions: are two
   marks enough, or should a song have both / a note? Should the automatic "Difficult" be merged with the "Hard" mark?
1. User to try the completed/difficult marks: is 5 wrong notes the right threshold (or should it scale with song length)?
   Should there be a way to reset a song's progress?
2. User to try the positions series (1 → 2 → 3) and the Fingers drills (1 → 4) with the real piano (Catalyst build) and say whether the finger numbers are enough
   (more notes? a toggle? position names like "F position" above the staff? finger numbers on the keyboard keys?).
   Also try the Songs sheet and importing the files in `TestSongs/`.
2. Import follow-ups, only if wanted: "Open in…" / AirDrop into the app (document types in `project.yml`), renaming songs,
   more bundled samples.
3. Staff view gaps: rests, beams for eighths, dotted notes, flats/key signatures, neighbouring chord notes (seconds)
   overlap, and the notes are spaced by time (not by engraving rules). Add only what the user asks for.
4. Milestone 3 (piano roll; the running clock, play/pause and tempo now exist as timed mode on the staff): **on hold (user's call, 2026-10-06).** Open questions
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
| 2026-10-06 | Fingering in `.mid` files: a lyric meta event with a single digit 1–5 right before the note-on (same tick, same track). MusicXML (milestone 7) will be the proper source later. |
| 2026-10-07 | Song categories (levels) for bundled samples = subfolders of SampleSongs; C-F-D positions go in "Intermediate III" (user's call). Imported songs stay flat in "My Songs". |
| 2026-10-07 | Position practices are a numbered series, each adding one position (1. C, 2. C + F, 3. C + F + D), 8 bars per position (user's call). |
| 2026-10-08 | User marks: one mark per song, **Hard** or **Interesting** (or none), kept apart from the automatic "Difficult"; marked songs get their own "Marked" section at the top of the Songs sheet. |
| 2026-10-08 | Timed mode: speed is a % of the song's tempo (keeps tempo changes); one-bar count-in; metronome on every quarter beat; ±½-beat hit window; missed = orange on the staff; missed + wrong count as mistakes for progress. |
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
