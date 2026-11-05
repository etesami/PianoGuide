import Foundation

/// Play-along: the app plays one staff while the player plays the other.
/// Pure logic, no clock or sound: the app tells it where the playhead is and plays what comes back.
public struct Accompaniment: Sendable {
    public struct Events: Equatable, Sendable {
        public var starts: [NoteEvent] = []
        public var stops: [UInt8] = []
    }

    private let notes: [NoteEvent]
    private var next = 0
    /// Notes started and not yet stopped.
    private var sounding: [(pitch: UInt8, endBeat: Double)] = []

    /// The notes on the staff the player is not playing.
    public init(song: Song, playerClef: Clef) {
        notes = song.notes.filter { StaffLayout.clef(for: $0) != playerClef }.sorted { $0.startBeat < $1.startBeat }
    }

    /// Every note has been started and has ended.
    public var isFinished: Bool { next >= notes.count && sounding.isEmpty }

    /// What to stop and start now that the playhead has reached `beat`.
    public mutating func advance(to beat: Double) -> Events {
        var events = Events()
        let ended = sounding.filter { $0.endBeat <= beat }
        sounding.removeAll { $0.endBeat <= beat }
        // Overlapping notes of one pitch: the key stays down until the last of them ends.
        events.stops = Set(ended.map(\.pitch)).filter { pitch in !sounding.contains { $0.pitch == pitch } }.sorted()
        while next < notes.count, notes[next].startBeat <= beat {
            let note = notes[next]
            events.starts.append(note)
            sounding.append((note.pitch, note.startBeat + note.durationBeats))
            next += 1
        }
        return events
    }

    /// Stops everything (pausing); returns the pitches to stop. Notes that were sounding don't come back on resume.
    public mutating func silence() -> [UInt8] {
        let pitches = Set(sounding.map(\.pitch)).sorted()
        sounding = []
        return pitches
    }

    /// Moves to `beat` (dragging the staff): the next note is the first one starting from there.
    public mutating func seek(to beat: Double) -> [UInt8] {
        next = notes.firstIndex { $0.startBeat >= beat } ?? notes.count
        return silence()
    }
}
