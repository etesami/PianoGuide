# Status & handoff

**Read this first when starting a new session.** Keep it current: update it at the end of every work session.

Last updated: 2026-10-06 (session 5: key labels and new key colors, verified with the real piano)

## Where we are

Milestones 0–2 and 4 are partly done (see the table in [PLAN.md §8](../PLAN.md#8-milestones)).

**Verified:**
- `PianoCore` package: the `Song` model, a Standard MIDI File parser and writer, `PracticeSteps` (groups chords),
  `WaitModeEngine`, and the sample song "Twinkle Twinkle" (`App/Resources/SampleSongs/twinkle.mid`).
  10 XCTest tests pass with `scripts/check-core.sh` (`swift test`); the package is in Swift 6 language mode (session 4).
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

**Not yet verified:** running on the real iPad; in-app Bluetooth pairing.

## Next steps (in order)

1. Milestone 3: build the **horizontal piano roll** view (a `Canvas` with notes moving right to left past a playhead), with play/pause and tempo.
2. Milestone 2 polish: import `.mid` files from the Files app (`fileImporter`) and keep a song library.
3. Later: switch the app target to Swift 6 (`SWIFT_VERSION` in `project.yml`; core types are already `Sendable`).

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
| 2026-10-06 | Hands in MIDI files: 2 or more note tracks means track 1 is the right hand and track 2 the left; a single track is split at middle C (60). |

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
