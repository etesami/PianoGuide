import Foundation

/// Minimal Standard MIDI File writer (format 1, one track per hand).
/// Used to build test fixtures and the bundled sample songs.
public enum MIDIFileWriter {
    public static func write(_ song: Song, ticksPerQuarter: Int = 480) -> Data {
        func ticks(_ beat: Double) -> Int { Int((beat * Double(ticksPerQuarter)).rounded()) }

        // Track 0: conductor (title, tempo). Then right hand, left hand.
        var conductor: [(tick: Int, bytes: [UInt8])] = [(0, meta(0x03, Array(song.title.utf8)))]
        for tempo in song.tempoMap {
            let us = tempo.microsecondsPerQuarter
            conductor.append((ticks(tempo.beat), meta(0x51, [UInt8(us >> 16 & 0xFF), UInt8(us >> 8 & 0xFF), UInt8(us & 0xFF)])))
        }
        var tracks = [conductor]
        for hands in [[Hand.right, .unknown], [.left]] {
            var events: [(tick: Int, bytes: [UInt8])] = []
            for note in song.notes where hands.contains(note.hand) {
                events.append((ticks(note.startBeat), [0x90, note.pitch, note.velocity]))
                events.append((ticks(note.startBeat + note.durationBeats), [0x80, note.pitch, 0]))
            }
            // Note-offs before note-ons at the same tick, so repeated notes stay separate.
            events.sort { ($0.tick, $0.bytes[0] == 0x80 ? 0 : 1) < ($1.tick, $1.bytes[0] == 0x80 ? 0 : 1) }
            tracks.append(events)
        }

        var out = Array("MThd".utf8) + be32(6) + be16(1) + be16(tracks.count) + be16(ticksPerQuarter)
        for events in tracks {
            var body: [UInt8] = []
            var last = 0
            for event in events {
                body += varLen(event.tick - last) + event.bytes
                last = event.tick
            }
            body += [0x00] + meta(0x2F, [])
            out += Array("MTrk".utf8) + be32(body.count) + body
        }
        return Data(out)
    }

    private static func meta(_ type: UInt8, _ payload: [UInt8]) -> [UInt8] {
        [0xFF, type] + varLen(payload.count) + payload
    }

    private static func be16(_ v: Int) -> [UInt8] { [UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
    private static func be32(_ v: Int) -> [UInt8] { be16(v >> 16) + be16(v) }

    static func varLen(_ value: Int) -> [UInt8] {
        var v = value
        var out = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            out.insert(UInt8(v & 0x7F) | 0x80, at: 0)
            v >>= 7
        }
        return out
    }
}

public enum SampleSongs {
    /// "Twinkle Twinkle Little Star" opening, right-hand melody + simple left-hand notes, 100 BPM.
    public static var twinkle: Song {
        let melody: [UInt8] = [60, 60, 67, 67, 69, 69, 67, 65, 65, 64, 64, 62, 62, 60]
        let lengths: [Double] = [1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2]
        var notes: [NoteEvent] = []
        var beat = 0.0
        for (pitch, length) in zip(melody, lengths) {
            notes.append(NoteEvent(id: notes.count, pitch: pitch, startBeat: beat,
                                   durationBeats: length * 0.95, velocity: 80, hand: .right))
            beat += length
        }
        // Left hand: one note per bar (4 beats): C3, F3/C3 ..., keeps it easy.
        for (bar, pitch) in ([48, 53, 48, 43] as [UInt8]).enumerated() {
            notes.append(NoteEvent(id: notes.count, pitch: pitch, startBeat: Double(bar * 4),
                                   durationBeats: 3.8, velocity: 70, hand: .left))
        }
        notes.sort { ($0.startBeat, $0.pitch) < ($1.startBeat, $1.pitch) }
        notes = notes.enumerated().map { i, n in var n = n; n = NoteEvent(id: i, pitch: n.pitch, startBeat: n.startBeat, durationBeats: n.durationBeats, velocity: n.velocity, hand: n.hand); return n }
        return Song(title: "Twinkle Twinkle", tempoMap: [TempoChange(beat: 0, microsecondsPerQuarter: 600_000)],
                    notes: notes)
    }
}
