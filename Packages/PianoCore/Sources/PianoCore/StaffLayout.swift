import Foundation

/// Where notes go on a grand staff (treble + bass). Pure math, no drawing.
public enum Clef: Sendable {
    case treble, bass

    /// Diatonic index of the bottom staff line (E4 for treble, G2 for bass).
    var bottomLineDiatonic: Int { self == .treble ? 30 : 18 }
}

/// How a note looks: which head, whether it has a stem, how many flags.
public enum NoteValue: Equatable, Sendable {
    case whole, half, quarter, eighth, sixteenth

    /// Rounds a MIDI duration (in quarter-note beats) to the nearest written value.
    /// MIDI notes are often released a little early, so the thresholds sit between values.
    public static func from(beats: Double) -> NoteValue {
        switch beats {
        case 3.5...: return .whole
        case 1.75...: return .half
        case 0.875...: return .quarter
        case 0.4375...: return .eighth
        default: return .sixteenth
        }
    }

    public var isHollow: Bool { self == .whole || self == .half }
    public var hasStem: Bool { self != .whole }
    public var flags: Int { self == .eighth ? 1 : self == .sixteenth ? 2 : 0 }
}

public struct StaffNote: Equatable, Sendable {
    public var clef: Clef
    /// Steps above the bottom staff line: 0 = bottom line, 1 = first space, 8 = top line, negative = below.
    public var position: Int
    public var sharp: Bool

    /// Positions of the ledger lines this note needs (always even, i.e. line positions).
    public var ledgerLines: [Int] {
        if position <= -2 { return Array(stride(from: -2, through: position, by: -2)) }
        if position >= 10 { return Array(stride(from: 10, through: position, by: 2)) }
        return []
    }

    /// Stems go down for notes on or above the middle line.
    public var stemUp: Bool { position < 4 }
}

public enum StaffLayout {
    /// Letter index (C=0 … B=6) for each pitch class; black keys are spelled as sharps.
    private static let letter = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6]

    /// Right hand on the treble staff, left hand on the bass staff; unknown hand splits at middle C.
    public static func clef(for note: NoteEvent) -> Clef {
        switch note.hand {
        case .right: return .treble
        case .left: return .bass
        case .unknown: return note.pitch >= 60 ? .treble : .bass
        }
    }

    public static func place(_ note: NoteEvent) -> StaffNote {
        let clef = clef(for: note)
        let pitch = Int(note.pitch)
        let diatonic = (pitch / 12 - 1) * 7 + letter[pitch % 12]
        return StaffNote(clef: clef, position: diatonic - clef.bottomLineDiatonic,
                         sharp: NoteName.isBlackKey(note.pitch))
    }
}

extension Song {
    /// Time signature in effect at the start (4/4 if the file has none).
    public var initialTimeSignature: TimeSignature {
        timeSignatures.first { $0.beat == 0 } ?? TimeSignature(beat: 0, numerator: 4, denominator: 4)
    }

    /// Beats (quarter notes) where bar lines go, after the start; the last one closes the bar the song ends in.
    public var barlineBeats: [Double] {
        var signatures = timeSignatures.sorted { $0.beat < $1.beat }
        if signatures.first?.beat != 0 { signatures.insert(initialTimeSignature, at: 0) }
        let end = durationBeats
        var bars: [Double] = []
        for (i, sig) in signatures.enumerated() {
            let barLength = sig.beatsPerBar
            guard barLength > 0 else { continue }
            let isLast = i + 1 == signatures.count
            let sectionEnd = isLast ? end : signatures[i + 1].beat
            var beat = sig.beat + barLength
            // The last section keeps going until the bar holding the song's end is closed.
            while isLast ? beat - barLength < sectionEnd - 1e-6 : beat <= sectionEnd + 1e-6 {
                bars.append(beat)
                beat += barLength
            }
        }
        return bars
    }
}
