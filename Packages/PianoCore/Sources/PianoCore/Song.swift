import Foundation

public enum Hand: String, Codable, Sendable {
    case left, right, unknown
}

public struct NoteEvent: Identifiable, Equatable, Sendable {
    public let id: Int                  // index in Song.notes (stable for a loaded song)
    public var pitch: UInt8             // MIDI note number, 60 = middle C (C4)
    public var startBeat: Double
    public var durationBeats: Double
    public var velocity: UInt8
    public var hand: Hand
    public var finger: Int?

    public init(id: Int, pitch: UInt8, startBeat: Double, durationBeats: Double,
                velocity: UInt8, hand: Hand = .unknown, finger: Int? = nil) {
        self.id = id
        self.pitch = pitch
        self.startBeat = startBeat
        self.durationBeats = durationBeats
        self.velocity = velocity
        self.hand = hand
        self.finger = finger
    }
}

public struct TempoChange: Equatable, Sendable {
    public var beat: Double
    public var microsecondsPerQuarter: Int   // 500_000 = 120 BPM

    public init(beat: Double, microsecondsPerQuarter: Int) {
        self.beat = beat
        self.microsecondsPerQuarter = microsecondsPerQuarter
    }

    public var bpm: Double { 60_000_000.0 / Double(microsecondsPerQuarter) }
}

public struct TimeSignature: Equatable, Sendable {
    public var beat: Double
    public var numerator: Int
    public var denominator: Int
}

public struct Song: Sendable {
    public var title: String
    public var tempoMap: [TempoChange]      // sorted by beat, first entry at beat 0
    public var timeSignatures: [TimeSignature]
    public var notes: [NoteEvent]           // sorted by startBeat, then pitch

    public init(title: String, tempoMap: [TempoChange] = [],
                timeSignatures: [TimeSignature] = [], notes: [NoteEvent]) {
        self.title = title
        var map = tempoMap.sorted { $0.beat < $1.beat }
        if map.first?.beat != 0 {
            map.insert(TempoChange(beat: 0, microsecondsPerQuarter: 500_000), at: 0)
        }
        self.tempoMap = map
        self.timeSignatures = timeSignatures
        self.notes = notes
    }

    /// Converts a beat position to seconds using the tempo map.
    public func seconds(atBeat beat: Double) -> Double {
        var total = 0.0
        for (i, tempo) in tempoMap.enumerated() {
            let nextBeat = i + 1 < tempoMap.count ? tempoMap[i + 1].beat : Double.infinity
            let end = min(beat, nextBeat)
            if end <= tempo.beat { break }
            total += (end - tempo.beat) * Double(tempo.microsecondsPerQuarter) / 1_000_000
        }
        return total
    }

    public var durationBeats: Double {
        notes.map { $0.startBeat + $0.durationBeats }.max() ?? 0
    }

    public var pitchRange: ClosedRange<UInt8>? {
        guard let lo = notes.map({ $0.pitch }).min(),
              let hi = notes.map({ $0.pitch }).max() else { return nil }
        return lo...hi
    }
}

public enum NoteName {
    private static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// 60 -> "C4"
    public static func of(_ pitch: UInt8) -> String {
        names[Int(pitch) % 12] + String(Int(pitch) / 12 - 1)
    }

    public static func isBlackKey(_ pitch: UInt8) -> Bool {
        [1, 3, 6, 8, 10].contains(Int(pitch) % 12)
    }
}
