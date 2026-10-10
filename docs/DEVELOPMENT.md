# Development guide

## Environment (dev Mac)

- Intel Mac (so no "Designed for iPad" on Mac; use Mac Catalyst), macOS 15, **Xcode 26.3** (Swift 6.2, iOS 26.2 SDK), XcodeGen in `/usr/local/bin`.
- Homebrew is installed at `/usr/local/bin/brew`.

## Core logic checks

```sh
scripts/check-core.sh                                   # = (cd Packages/PianoCore && swift test)
scripts/check-core.sh --write-samples App/Resources/SampleSongs   # regenerate sample .mid files
scripts/check-core.sh --write-test-songs TestSongs                # regenerate the import test songs
```

The package uses `swift-tools-version:6.0`, so `PianoCore` builds in Swift 6 language mode (strict concurrency).
Add tests in `Packages/PianoCore/Tests/PianoCoreTests/` (XCTest). A test checks that the bundled `twinkle.mid`
matches `SampleSongs.twinkle`, so regenerate it after changing the sample song; likewise `TestSongs/*.mid` must match `TestSongs`.

## Generate & run the app

```sh
xcodegen generate          # creates PianoGuide.xcodeproj from project.yml (re-run after adding files)
open PianoGuide.xcodeproj
```

Choose an iPad simulator and press Run (⌘R). In the simulator, tap the on-screen keys to play.

To put a test song in the simulator's library without the file picker, copy it into the app's container and
set the last song in the app's own preferences file (`simctl spawn … defaults write` writes elsewhere and has no effect):

```sh
C=$(xcrun simctl get_app_container $SIM com.esnetsm.pianoguide data)
cp song.mid "$C/Documents/Songs/"
plutil -replace lastSong -string song.mid "$C/Library/Preferences/com.esnetsm.pianoguide.plist"   # app not running
```

If screenshots stop changing (the status-bar clock is stuck), the simulator display has frozen: `xcrun simctl shutdown $SIM` and boot it again.

From the command line (this is how it was verified):

```sh
SIM=8BB7E31C-6DC6-4179-A753-FB7036ACB7B4     # iPad Pro 11-inch (M5); list with: xcrun simctl list devices available
xcodebuild -project PianoGuide.xcodeproj -scheme PianoGuide \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath .build/DerivedData build
xcrun simctl boot $SIM; open -a Simulator
xcrun simctl install $SIM .build/DerivedData/Build/Products/Debug-iphonesimulator/PianoGuide.app
xcrun simctl launch $SIM com.esnetsm.pianoguide
xcrun simctl io $SIM screenshot shot.png
```

## Test with the piano on the Mac (Mac Catalyst)

The simulator can't see MIDI devices plugged into the Mac, so to play the real FP-30X on the dev Mac,
run the app as a Mac Catalyst app (enabled by `SUPPORTS_MACCATALYST` in `project.yml`):

1. Connect the FP-30X to the Mac with USB (the piano's **USB Computer** port). Check it appears in
   Audio MIDI Setup → Window → Show MIDI Studio as "Roland Digital Piano".
2. In Xcode choose **My Mac (Mac Catalyst)** and press Run, or from the command line. Mac builds are signed to run locally
   (`CODE_SIGN_IDENTITY[sdk=macosx*]: "-"` in `project.yml`), so no certificate is needed:

```sh
xcodegen generate
xcodebuild -project PianoGuide.xcodeproj -scheme PianoGuide -destination "platform=macOS,variant=Mac Catalyst" \
  -derivedDataPath .build/DerivedData build
open .build/DerivedData/Build/Products/Debug-maccatalyst/PianoGuide.app
```

3. Screenshot the window (needs Screen Recording permission for the terminal app):

```sh
WID=$(swift -e 'import CoreGraphics; let l = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String:Any]]; for w in l where (w["kCGWindowOwnerName"] as? String) == "PianoGuide" { print(w["kCGWindowNumber"]!); break }')
screencapture -x -l $WID shot.png
```

Bluetooth also works on the Mac: pair the piano in Audio MIDI Setup → MIDI Studio → Bluetooth (not in System Settings).

## Install on iPad

1. Connect the iPad by USB-C and tap **Trust** on the iPad.
2. The Apple ID and team are already set up (`DEVELOPMENT_TEAM` in `project.yml`, so it survives `xcodegen generate`).
3. Choose the iPad as the run destination and press Run.
4. On the iPad, the first time: **Settings → Privacy & Security → Developer Mode → On** (the iPad restarts), then
   **Settings → General → VPN & Device Management** → trust your developer certificate.
5. With a free Apple ID the app stops launching after **7 days**. Press Run again in Xcode to re-sign it.

## Connect the Roland FP-30X

1. Turn on the piano's Bluetooth. Press the button to switch to MIDI mode if needed; see the FP-30X manual for "Bluetooth MIDI".
2. In PianoGuide, tap the **Bluetooth** toolbar button → choose the FP-30X → **Connect**. Don't pair it in iOS Settings.
3. Close the sheet. The header should show "Connected: …", and pressing piano keys lights up the on-screen keys.

## Code map

| Path | What |
|---|---|
| `Packages/PianoCore/Sources/PianoCore/Song.swift` | `Song`, `NoteEvent`, tempo map (`seconds(atBeat:)`), `NoteName` |
| `…/MIDIFileParser.swift` | `.mid` → `Song` (format 0/1, running status, hand assignment, fingers from lyric events) |
| `…/MIDIFileWriter.swift` | `Song` → `.mid` (format 1 per hand, or single-track format 0; tempo and time signatures), plus `SampleSongs` |
| `…/PositionSongs.swift` | `FivePosition` (C/F/D finger → key) and `PositionPractice`: the positions series (1. C, 2. C + F, 3. C + F + D), right hand and both hands |
| `…/FingerSongs.swift` | `FingerPractice`: five-finger coordination drills (pairs, skips, mirror, parallel) |
| `…/TestSongs.swift` | Songs for trying the import ("Ode to Joy", "Minuet in G"); written to `TestSongs/` |
| `…/WaitModeEngine.swift` | `PracticeSteps` (chord grouping) and the wait-mode state machine |
| `…/StaffLayout.swift` | Staff positions (clef, line/space, sharps, ledger lines), `NoteValue`, bar lines |
| `…/SongProgress.swift` | Per-song progress: times completed, recent wrong notes, "difficult" rule (5+ wrong notes); the user's own `SongMark` (hard / interesting) |
| `…/PracticeNote.swift` | Lesson note parsed from a small Markdown subset (title, headings, bullets, paragraphs) and `StaffExample` (```` ```staff ```` music examples) |
| `App/Resources/SampleSongs/<level>/x.md` | Lesson note for `x.mid`, shown when the song is picked |
| `App/Sources/PracticeNoteView.swift` | Sheet showing a lesson note (scrolls; "Start Practice" closes it) |
| `App/Sources/MIDIInputService.swift` | CoreMIDI: connects all sources and publishes note on/off (also simulated events) |
| `App/Sources/BluetoothMIDIPairingView.swift` | Wraps `CABTMIDICentralViewController` |
| `App/Sources/PracticeView.swift` | Main screen: wait mode on the chosen song (staff + keyboard); remembers the last song |
| `App/Sources/SongLibrary.swift` | Bundled samples (subfolders = categories) + imported `.mid` files (copied to Documents/Songs); import, delete, load; each song's `SongProgress` (UserDefaults `songProgress`) |
| `App/Sources/SongLibraryView.swift` | "Songs" sheet: category folders, pick a song, swipe to delete, Import button (`fileImporter`); completed (green check) and difficult (orange) marks; user marks (swipe right / long-press, "Marked" section); `SongMarkPicker` (also used by the flag button in `PracticeView`) |
| `App/Sources/StaffView.swift` | Grand staff drawn in a `Canvas`, scrolling past the cursor (`scrollBeat` is animatable) |
| `App/Sources/KeyboardView.swift` | On-screen piano that can be tapped; note-name labels and key colors |

## Conventions

- Keep music logic in `PianoCore` (pure Swift, no UIKit/SwiftUI) so it can be tested without a device.
- Update `docs/STATUS.md` (progress, next steps, decisions) at the end of each session.
