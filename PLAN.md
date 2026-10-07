# PianoGuide: Plan

An iPad app that loads a piece of music, shows its notes on screen, listens to a
Bluetooth MIDI keyboard, and guides the player by highlighting and scrolling the notes
as they play.

Status: **approved, in progress.** Current progress and next steps are in [docs/STATUS.md](docs/STATUS.md);
build and test instructions are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

---

## 1. Goals

**MVP (v0.1)**
1. Import a song from a file (see §3 for formats).
2. Connect to a piano/keyboard over **Bluetooth MIDI** (and USB MIDI, which comes for free).
3. Show the notes on screen with a playhead that scrolls.
4. Detect the notes the user plays, and mark each expected note as correct, wrong or missed.
5. Two practice modes:
   - **Wait mode:** the song pauses until the right note or chord is played. This is best for learning.
   - **Play-along mode:** the song moves at a set tempo (adjustable from 50% to 100%) and the app scores timing.

**Later**
- Practice each hand separately (left, right or both)
- Loop a section (A–B repeat)
- Metronome, plus the app playing the accompaniment or the other hand
- Show traditional staff notation (see §4)
- Practice stats and history
- Simple fingering hints when the file includes them

**Not planned:** an app store release, accounts or cloud sync, or audio (microphone)
pitch detection. The app uses MIDI only, which is precise and avoids hard audio-analysis work.

---

## 2. Platform & prerequisites

| Item            | Choice                                                                                                                                                                           |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Device          | iPad (iPadOS 17+). It also builds as a Mac Catalyst app, which is how we test with the real piano on the (Intel) dev Mac.                                                       |
| Language / UI   | Swift 6 and SwiftUI. The note view uses SwiftUI `Canvas`, with Metal kept as an option if it needs more speed.                                                                   |
| MIDI            | Apple's **CoreMIDI**, plus **CoreAudioKit**'s `CABTMIDICentralViewController`, the built-in screen for pairing Bluetooth MIDI devices.                                           |
| Helper library  | **None for now.** We wrote our own small MIDI file parser and use CoreMIDI directly; [MIDIKit](https://github.com/orchetect/MIDIKit) stays an option if MIDI handling grows. |
| Project file    | [XcodeGen](https://github.com/yonaskolb/XcodeGen) `project.yml`, which keeps the repo clean and easy to diff. **Decided.** |
| Install on iPad | Run it from Xcode with your Apple ID (free accounts re-sign every 7 days, paid accounts every year)                                                                              |

---

## 3. Music input format: what's typical

| Format                             | What it is                                                            | Pros                                                                           | Cons                                                                                              |
| ---------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| **Standard MIDI File (`.mid`)**    | Timed note-on/off events per track                                    | Everywhere (free downloads, every DAW exports it); exact timing; easy to parse | No real notation: hands are guessed from tracks or pitch, and there is no clean bar/beat spelling |
| **MusicXML (`.musicxml`, `.mxl`)** | Standard format for sheet music (MuseScore, Finale, Sibelius, Dorico) | Real notation: staves, hands, measures, key, fingering                         | More complex to parse; needed for staff display                                                   |
| ABC / LilyPond / MEI               | Text notation formats                                                 | Compact                                                                        | Niche, not worth supporting at first                                                              |

**Recommendation:** start with **MIDI files** in the MVP because they are simplest and most common,
and add **MusicXML** in v0.2. Both import into one **internal model**, so the rest of the app
never sees the file format:

```swift
struct Song {
    var title: String
    var tempoMap: [TempoChange]        // beats → seconds
    var timeSignatures: [TimeSignature]
    var notes: [NoteEvent]             // sorted by start
}

struct NoteEvent: Identifiable {
    let id: Int                        // index in Song.notes
    var pitch: UInt8                   // MIDI note number 21…108 (A0…C8)
    var startBeat: Double
    var durationBeats: Double
    var velocity: UInt8
    var hand: Hand                     // .left / .right / .unknown
    var finger: Int?                   // 1…5 if known
}
```

How the app picks the hand for each note in a MIDI file: with 2 or more note tracks, track 1 is the
right hand and track 2 the left (common in piano files); a single track is split at middle C
(C4 and above is the right hand).

Ways to get songs into the app: the Files app or AirDrop through "Open in…", plus a few
bundled sample songs for testing.

---

## 4. Display: horizontal vs vertical scrolling

| Option                             | Looks like                                                                 | Good for                                                                  | Effort                                                                                                        |
| ---------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| **A. Falling notes (vertical)**    | Synthesia style: colored bars fall onto an on-screen keyboard              | Beginners; you see exactly which key to press; maps 1:1 onto the keyboard | **Low.** Bars are just rectangles.                                                                            |
| **B. Piano roll (horizontal)**     | Bars move right to left past a playhead line, with keys down the left side | Seeing phrases, DAW-like                                                  | Low                                                                                                           |
| **C. Staff notation (horizontal)** | Real sheet music scrolling past a playhead                                 | Learning to *read* music                                                  | **High.** Laying out real notation is hard; a renderer such as [Verovio](https://www.verovio.org) would help. |

**Decided: B (horizontal piano roll) first.** *Update 2026-10-06: the user asked for C (staff) now; a basic version exists.* The renderer sits behind a protocol (`NoteVisualizer`)
so falling notes or **C (staff)** can be added later without touching the MIDI or practice logic.

On-screen keyboard: an 88-key strip at the bottom that zooms to the song's note range.
Keys you **play** turn green when correct and red when wrong. After a wrong note, the keys still
needed turn orange. Each key can show its note name (toggle in the toolbar).

---

## 5. Architecture

```
┌──────────────┐   ┌────────────────┐   ┌──────────────────┐
│ Importers    │──▶│ Song (model)   │──▶│ PracticeEngine   │◀── MIDI input events
│ MIDI/MusicXML│   └────────────────┘   │ (clock, matching,│      (MIDIService)
└──────────────┘                        │  wait/tempo mode)│
                                        └────────┬─────────┘
                                                 │ state: current time, note statuses
                                                 ▼
                                        ┌──────────────────┐
                                        │ Views (SwiftUI)  │
                                        │ PianoRollView    │
                                        │ KeyboardView     │
                                        │ Transport/Controls│
                                        └──────────────────┘
```

**Modules** (local Swift packages, so the core logic can be unit-tested without the UI or hardware):

- `PianoCore`: the `Song` model, importers, and `PracticeEngine`. Pure Swift with no UIKit,
  and covered heavily by tests.
- `PianoMIDI` (*for now this lives in the app target as `App/Sources/MIDIInputService.swift`; split it into a package once it grows*): `MIDIService`, which wraps CoreMIDI. It finds sources, connects to them,
  publishes `noteOn`/`noteOff` events, and handles Bluetooth pairing through `CABTMIDICentralViewController`.
- `App`: the SwiftUI screens (Library, Practice, Settings) and the renderers.

### Note-matching logic (the core of the app)
- Notes are grouped into **chords**: expected notes that start within 1/32 of a beat of each other count as one step (`PracticeSteps.make`).
- **Wait mode:** the clock stops at the next step. The step passes once all of its pitches have been pressed,
  in any order, while still held down (releasing a chord note before the chord is complete un-counts it).
  Wrong notes are flagged but don't move the song forward. Implemented in `WaitModeEngine`.
- **Play-along mode:** each expected note has a hit window (for example ±150 ms, adjustable).
  A note played inside the window counts as a hit and records its timing error. Expected notes
  that pass without being played count as missed, and played notes that match nothing count as extra.
- Latency: Bluetooth MIDI adds about 10–20 ms. We'll add a calibration setting (an offset in ms).

### Timing
- Use `CADisplayLink` for drawing and MIDI timestamps (host time) for scoring. Never use the frame time for scoring.

---

## 6. Testing without a piano nearby
- **On-screen keyboard input**: tap the keys to send the same events a real keyboard would.
- **Virtual MIDI source** (debug builds): play back a MIDI file as "user input" to test the
  matching logic automatically.
- **Mac**: run the app as a Mac Catalyst app with the FP-30X on USB (or Bluetooth via *Audio MIDI Setup*).
  The iPad simulator can't see the Mac's MIDI devices.
- **Unit tests**: tests for the importers (using fixture `.mid` files) and the matching engine (using made-up event streams).

---

## 7. Repo layout (current)

```
PianoGuide/
├── PLAN.md                     # this file: the what and why
├── CLAUDE.md                   # entry point for new AI sessions
├── README.md
├── project.yml                 # XcodeGen spec → PianoGuide.xcodeproj (generated, git-ignored)
├── docs/
│   ├── STATUS.md               # progress, next steps, known issues (keep up to date)
│   └── DEVELOPMENT.md          # environment, build, test, install on iPad
├── scripts/check-core.sh       # runs the PianoCore unit tests (swift test)
├── App/
│   ├── Sources/                # SwiftUI app: PracticeView, KeyboardView, MIDIInputService, Bluetooth pairing
│   └── Resources/SampleSongs/  # twinkle.mid (generated by scripts/check-core.sh --write-samples)
└── Packages/
    └── PianoCore/              # Song model, MIDI file parser/writer, PracticeSteps, WaitModeEngine
        ├── Sources/write-samples/    # writes the sample .mid files
        └── Tests/PianoCoreTests/     # XCTest unit tests
```

Note: `Info.plist` is generated from `project.yml` (`INFOPLIST_KEY_*` settings). It has
`NSBluetoothAlwaysUsageDescription` for Bluetooth MIDI; later it also needs `UISupportsDocumentBrowser` /
document types so the app can open `.mid` and `.musicxml` files.

---

## 8. Milestones

| #   | Milestone           | Done when                                                                                           | Status |
| --- | ------------------- | --------------------------------------------------------------------------------------------------- | ------ |
| 0   | **Scaffold**        | The project builds and runs on your iPad and shows a placeholder screen; the packages and tests run | 🟡 builds and runs in the simulator; not yet on the iPad |
| 1   | **MIDI in**         | The app pairs a Bluetooth MIDI keyboard; pressed keys light up the on-screen keyboard               | 🟡 verified with the FP-30X over USB in the Mac Catalyst build; Bluetooth on iPad not yet tested |
| 2   | **Import & model**  | A `.mid` file loads into `Song`; the note list shows in a debug view; importer tests pass           | 🟡 parser done and tested; no file picker yet |
| 3   | **Piano roll**      | The song scrolls smoothly at 60/120 fps with a playhead, play/pause and tempo slider                | ⬜ |
| 4   | **Wait mode**       | The song waits for the correct note or chord, with correct and wrong feedback                       | 🟡 engine done and tested; works with the real piano (Mac Catalyst), with green/red/orange key feedback |
| 5   | **Play-along mode** | Hit windows, scoring, and a summary at the end of the song                                          | ⬜ |
| 6   | **Polish**          | Hand selection, A–B loop, metronome, latency calibration                                            | ⬜ |
| 7   | **MusicXML**        | MusicXML import (hands and fingering come from the file)                                            | ⬜ |
| 8   | **Staff view**      | A second renderer that shows staff notation                                                         | 🟡 basic grand staff with cursor and note colors in wait mode (session 6); no rests, beams, dots, flats yet |

Legend: ⬜ not started · 🟡 in progress · ✅ done (verified on iPad).

---

## 9. Decisions (answered by you)

1. **Display style:** a horizontal piano roll
2. **File formats:** support MIDI files first and later we support MusicXML.
3. **Keyboard:** Roland FP-30X. It supports Bluetooth MIDI itself.
4. **Apple account:** I have an Apple ID (free).
5. **Project file:** Use XcodeGen (`project.yml`).
6. **Name:** "PianoGuide", bundle ID `com.esnetsm.pianoguide`.
7. **GitHub:** I will push later.
