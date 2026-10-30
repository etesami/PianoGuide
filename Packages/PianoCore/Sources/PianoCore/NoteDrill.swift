import Foundation

/// Note-finding drill: endless random notes taken from the pitches a song uses, judged like wait mode.
/// With one clef, each prompt is a single note on that staff; with both, it is one treble note and one bass note
/// pressed together. A prompt never repeats the one before it (when the song has more than one choice).
public struct NoteDrill: Sendable {
    public private(set) var engine: WaitModeEngine
    /// The staff whose notes are asked for (nil = both).
    public let clef: Clef?
    /// The notes asked for now; their IDs are the drill's own (they count up), not the song's.
    public private(set) var current: [NoteEvent] = []
    /// Distinct pitches the song uses on each staff (empty when that staff is not in the drill).
    private let treble: [UInt8]
    private let bass: [UInt8]
    private var nextID = 0
    private var random: SplitMix64

    public init(song: Song, clef: Clef? = nil, seed: UInt64 = .random(in: 0...UInt64.max)) {
        func pitches(on staff: Clef) -> [UInt8] {
            guard clef == nil || clef == staff else { return [] }
            return Set(song.notes.filter { StaffLayout.clef(for: $0) == staff }.map(\.pitch)).sorted()
        }
        self.clef = clef
        treble = pitches(on: .treble)
        bass = pitches(on: .bass)
        random = SplitMix64(state: seed)
        engine = WaitModeEngine(steps: [])
        addPrompt()
    }

    /// False when the song has no notes for the chosen hand.
    public var hasNotes: Bool { !current.isEmpty }
    /// Prompts found so far.
    public var foundCount: Int { engine.currentIndex }

    public mutating func noteOn(_ pitch: UInt8) -> WaitModeEngine.Feedback {
        let feedback = engine.noteOn(pitch)
        if case .stepCompleted = feedback { addPrompt() }
        return feedback
    }

    public mutating func noteOff(_ pitch: UInt8) {
        engine.noteOff(pitch)
    }

    private mutating func addPrompt() {
        var picked: [(pitch: UInt8, hand: Hand)] = []
        for _ in 0..<20 {
            picked = []
            if let pitch = treble.randomElement(using: &random) { picked.append((pitch, .right)) }
            // A pitch both hands use in the song can't be asked for on both staves at once.
            if let pitch = bass.filter({ $0 != picked.first?.pitch }).randomElement(using: &random) { picked.append((pitch, .left)) }
            if Set(picked.map(\.pitch)) != engine.steps.last?.pitches { break }
        }
        guard !picked.isEmpty else { return }
        // The hand puts each note on its staff (StaffLayout.clef), even a left-hand C4.
        current = picked.map { pitch, hand in
            nextID += 1
            return NoteEvent(id: nextID, pitch: pitch, startBeat: 0, durationBeats: 4, velocity: 80, hand: hand)
        }
        engine.append(PracticeStep(startBeat: Double(engine.steps.count), noteIDs: current.map(\.id),
                                   notePitches: current.map(\.pitch), pitches: Set(current.map(\.pitch))))
    }
}

/// Small seedable random generator, so drills can be repeated in tests.
struct SplitMix64: RandomNumberGenerator, Sendable {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
