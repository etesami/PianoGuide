import Foundation

/// Parses Standard MIDI Files (format 0 and 1) into a `Song`.
/// No dependencies on purpose: it is small and easy to test.
///
/// Fingering (our own convention, since MIDI has no standard for it): a lyric event whose text is a single
/// digit 1–5, placed just before a note-on at the same tick in the same track, is that note's finger.
public enum MIDIFileParser {
    public enum ParseError: Error, Equatable {
        case notAMIDIFile
        case unsupportedFormat(Int)
        case smpteTimingNotSupported
        case truncated
    }

    public static func parse(_ data: Data, title: String = "Untitled") throws -> Song {
        var r = ByteReader(bytes: [UInt8](data))

        guard try r.string(4) == "MThd" else { throw ParseError.notAMIDIFile }
        let headerLength = Int(try r.uint32())
        let format = Int(try r.uint16())
        let trackCount = Int(try r.uint16())
        let division = Int(try r.uint16())
        try r.skip(headerLength - 6)
        guard format == 0 || format == 1 else { throw ParseError.unsupportedFormat(format) }
        guard division & 0x8000 == 0 else { throw ParseError.smpteTimingNotSupported }
        let ticksPerQuarter = Double(division)

        var tempoMap: [TempoChange] = []
        var timeSignatures: [TimeSignature] = []
        var trackName: String?
        // Notes per track, before hand assignment.
        var trackNotes: [[RawNote]] = []

        for _ in 0..<trackCount {
            guard try r.string(4) == "MTrk" else { throw ParseError.truncated }
            let length = Int(try r.uint32())
            var t = ByteReader(bytes: try r.bytes(length))

            var tick = 0
            var runningStatus: UInt8 = 0
            var open: [Int: [(tick: Int, velocity: UInt8, finger: Int?)]] = [:]   // key: channel<<8 | pitch
            var pendingFinger: (tick: Int, finger: Int)?   // from a lyric "1"…"5", for the next note-on
            var notes: [RawNote] = []

            func close(_ key: Int, at tick: Int) {
                guard var starts = open[key], !starts.isEmpty else { return }
                let start = starts.removeFirst()
                open[key] = starts
                notes.append(RawNote(pitch: UInt8(key & 0xFF), startTick: start.tick,
                                     endTick: tick, velocity: start.velocity, finger: start.finger))
            }

            while !t.isAtEnd {
                tick += try t.varLen()
                var status = try t.uint8()
                if status < 0x80 {          // running status: reuse previous, this byte is data
                    t.position -= 1
                    status = runningStatus
                } else if status < 0xF0 {
                    runningStatus = status
                }

                switch status {
                case 0xFF:                  // meta event
                    let type = try t.uint8()
                    let payload = try t.bytes(try t.varLen())
                    let beat = Double(tick) / ticksPerQuarter
                    switch type {
                    case 0x51 where payload.count == 3:
                        let us = Int(payload[0]) << 16 | Int(payload[1]) << 8 | Int(payload[2])
                        tempoMap.append(TempoChange(beat: beat, microsecondsPerQuarter: us))
                    case 0x58 where payload.count >= 2:
                        timeSignatures.append(TimeSignature(beat: beat, numerator: Int(payload[0]),
                                                            denominator: 1 << Int(payload[1])))
                    case 0x05:
                        if payload.count == 1, (UInt8(ascii: "1")...UInt8(ascii: "5")).contains(payload[0]) {
                            pendingFinger = (tick, Int(payload[0] - UInt8(ascii: "0")))
                        }
                    case 0x03 where trackName == nil:
                        trackName = String(bytes: payload, encoding: .utf8)
                    default:
                        break
                    }
                case 0xF0, 0xF7:            // sysex
                    try t.skip(try t.varLen())
                default:
                    let channel = Int(status & 0x0F)
                    switch status & 0xF0 {
                    case 0x90:
                        let pitch = try t.uint8(), velocity = try t.uint8()
                        let key = channel << 8 | Int(pitch)
                        if velocity == 0 {
                            close(key, at: tick)
                        } else {
                            let finger = pendingFinger?.tick == tick ? pendingFinger?.finger : nil
                            pendingFinger = nil
                            open[key, default: []].append((tick, velocity, finger))
                        }
                    case 0x80:
                        let pitch = try t.uint8()
                        _ = try t.uint8()
                        close(channel << 8 | Int(pitch), at: tick)
                    case 0xA0, 0xB0, 0xE0:
                        try t.skip(2)
                    case 0xC0, 0xD0:
                        try t.skip(1)
                    default:
                        throw ParseError.truncated
                    }
                }
            }
            // Close notes that never got a note-off at the end of the track.
            for key in open.keys {
                while let starts = open[key], !starts.isEmpty { close(key, at: tick) }
            }
            if !notes.isEmpty { trackNotes.append(notes) }
        }

        let notes = assignHands(trackNotes)
            .sorted { ($0.0.startTick, $0.0.pitch) < ($1.0.startTick, $1.0.pitch) }
            .enumerated()
            .map { index, item -> NoteEvent in
                let (raw, hand) = item
                return NoteEvent(id: index, pitch: raw.pitch,
                                 startBeat: Double(raw.startTick) / ticksPerQuarter,
                                 durationBeats: Double(raw.endTick - raw.startTick) / ticksPerQuarter,
                                 velocity: raw.velocity, hand: hand, finger: raw.finger)
            }

        return Song(title: trackName ?? title, tempoMap: tempoMap,
                    timeSignatures: timeSignatures, notes: notes)
    }

    /// Two or more note tracks: first = right hand, second = left hand (common for piano files).
    /// One track: split at middle C.
    static func assignHands(_ tracks: [[RawNote]]) -> [(RawNote, Hand)] {
        if tracks.count >= 2 {
            return tracks.enumerated().flatMap { index, notes in
                notes.map { ($0, index == 0 ? Hand.right : index == 1 ? Hand.left : Hand.unknown) }
            }
        }
        return tracks.flatMap { $0 }.map { ($0, $0.pitch >= 60 ? Hand.right : Hand.left) }
    }

    struct RawNote {
        var pitch: UInt8
        var startTick: Int
        var endTick: Int
        var velocity: UInt8
        var finger: Int?
    }
}

struct ByteReader {
    let bytes: [UInt8]
    var position = 0

    var isAtEnd: Bool { position >= bytes.count }

    mutating func uint8() throws -> UInt8 {
        guard position < bytes.count else { throw MIDIFileParser.ParseError.truncated }
        defer { position += 1 }
        return bytes[position]
    }

    mutating func uint16() throws -> UInt16 {
        UInt16(try uint8()) << 8 | UInt16(try uint8())
    }

    mutating func uint32() throws -> UInt32 {
        UInt32(try uint16()) << 16 | UInt32(try uint16())
    }

    mutating func bytes(_ count: Int) throws -> [UInt8] {
        guard count >= 0, position + count <= bytes.count else { throw MIDIFileParser.ParseError.truncated }
        defer { position += count }
        return Array(bytes[position..<position + count])
    }

    mutating func skip(_ count: Int) throws { _ = try bytes(count) }

    mutating func string(_ count: Int) throws -> String {
        String(bytes: try bytes(count), encoding: .ascii) ?? ""
    }

    /// MIDI variable-length quantity (7 bits per byte, high bit = continue).
    mutating func varLen() throws -> Int {
        var value = 0
        for _ in 0..<4 {
            let byte = try uint8()
            value = value << 7 | Int(byte & 0x7F)
            if byte & 0x80 == 0 { return value }
        }
        throw MIDIFileParser.ParseError.truncated
    }
}
