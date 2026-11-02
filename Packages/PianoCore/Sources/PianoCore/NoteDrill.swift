import Foundation

/// Note-finding drill: endless random notes taken from the pitches a song uses, judged like wait mode.
/// With one clef, each prompt is a single note on that staff; with both, it is one treble note and one bass note
/// pressed together. A prompt never repeats the one before it (when the song has more than one choice).
/// A found prompt stays (shown as played) until all its keys are let go; then the next one comes.
/// Notes are picked by `NoteDrillStats.shares`, so the ones missed lately come up more often than the others.
public struct NoteDrill: Sendable {
    public private(set) var engine: WaitModeEngine
    /// The staff whose notes are asked for (nil = both).
    public let clef: Clef?
    /// The notes asked for now; their IDs are the drill's own (they count up), not the song's.
    public private(set) var current: [NoteEvent] = []
    /// Distinct pitches the song uses on each staff (empty when that staff is not in the drill).
    private let treble: [UInt8]
    private let bass: [UInt8]
    /// How often each note was missed; updated as prompts are found, for the app to save.
    public private(set) var stats: NoteDrillStats
    /// IDs of the current prompt's notes that a wrong key was blamed on.
    private var missedIDs: Set<Int> = []
    private var nextID = 0
    /// Keys down now, so the next prompt can wait until the found one's keys are up.
    private var held: Set<UInt8> = []
    private var random: SplitMix64

    public init(song: Song, clef: Clef? = nil, stats: NoteDrillStats = NoteDrillStats(), seed: UInt64 = .random(in: 0...UInt64.max)) {
        func pitches(on staff: Clef) -> [UInt8] {
            guard clef == nil || clef == staff else { return [] }
            return Set(song.notes.filter { StaffLayout.clef(for: $0) == staff }.map(\.pitch)).sorted()
        }
        self.clef = clef
        self.stats = stats
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
    /// The current prompt was found and its keys are still down; keys pressed meanwhile are not judged.
    public var isFound: Bool { hasNotes && engine.isFinished }

    public mutating func noteOn(_ pitch: UInt8) -> WaitModeEngine.Feedback {
        held.insert(pitch)
        let feedback = engine.noteOn(pitch)
        switch feedback {
        case .wrong:
            // With two notes asked for, the wrong key was most likely meant for the nearer one still to be pressed.
            let distance = { (note: NoteEvent) in abs(Int(note.pitch) - Int(pitch)) }
            if let blamed = current.filter({ !engine.hitInCurrentStep.contains($0.pitch) }).min(by: { distance($0) < distance($1) }) {
                missedIDs.insert(blamed.id)
            }
        case .stepCompleted:
            for note in current {
                stats.record(pitch: note.pitch, clef: StaffLayout.clef(for: note), missed: missedIDs.contains(note.id))
            }
            missedIDs = []
        default:
            break
        }
        return feedback
    }

    public mutating func noteOff(_ pitch: UInt8) {
        held.remove(pitch)
        engine.noteOff(pitch)
        if isFound, held.isDisjoint(with: current.map(\.pitch)) { addPrompt() }
    }

    private mutating func addPrompt() {
        var picked: [(pitch: UInt8, hand: Hand)] = []
        if let pitch = pick(from: treble, on: .treble, previous: current.first { $0.hand == .right }?.pitch) {
            picked.append((pitch, .right))
        }
        // A pitch both hands use in the song can't be asked for on both staves at once.
        if let pitch = pick(from: bass.filter({ $0 != picked.first?.pitch }), on: .bass, previous: current.first { $0.hand == .left }?.pitch) {
            picked.append((pitch, .left))
        }
        guard !picked.isEmpty else { return }
        // The hand puts each note on its staff (StaffLayout.clef), even a left-hand C4.
        current = picked.map { pitch, hand in
            nextID += 1
            return NoteEvent(id: nextID, pitch: pitch, startBeat: 0, durationBeats: 1, velocity: 80, hand: hand)
        }
        engine.append(PracticeStep(startBeat: Double(engine.steps.count), noteIDs: current.map(\.id),
                                   notePitches: current.map(\.pitch), pitches: Set(current.map(\.pitch))))
    }

    /// A random pitch by its share, leaving out the one asked for last on this staff (unless there is no other).
    private mutating func pick(from pitches: [UInt8], on staff: Clef, previous: UInt8?) -> UInt8? {
        let choices = zip(pitches, stats.shares(of: pitches, clef: staff)).map { (pitch: $0, share: $1) }
        let fresh = choices.filter { $0.pitch != previous }
        let pool = fresh.isEmpty ? choices : fresh
        var draw = Double.random(in: 0..<1, using: &random) * pool.reduce(0) { $0 + $1.share }
        for choice in pool {
            draw -= choice.share
            if draw < 0 { return choice.pitch }
        }
        return pool.last?.pitch
    }
}

/// How often each note was missed in the note drill: a prompt counts once per note, however many wrong keys it took.
/// Kept per written note (staff and pitch), not per song: a C4 on the bass staff is read differently from one on the
/// treble staff, but it is the same note in every song.
///
/// A note's share of the prompts comes from its recent miss rate:
/// - Only that note's own last ten or so prompts count (`memory`), so getting it right brings its share back down.
/// - A first slip doesn't count as a 100% miss rate: three imagined clean prompts soften it (`priorAttempts`).
/// - Each note has a weight of 1 plus up to `maxBoost` for its miss rate, so no mistakes means all notes come up evenly.
/// - All the boosts together may not outweigh the base weights, so at least half of the prompts stay evenly spread and
///   every note keeps at least half of its even share, however many notes are weak.
public struct NoteDrillStats: Codable, Equatable, Sendable {
    private struct Record: Codable, Equatable, Sendable {
        var attempts = 0.0
        var misses = 0.0
    }

    private static let memory = 0.9
    private static let priorAttempts = 3.0
    private static let maxBoost = 5.0

    private var records: [String: Record] = [:]

    public init() {}

    private func key(_ pitch: UInt8, _ clef: Clef) -> String { "\(clef == .treble ? "treble" : "bass") \(pitch)" }

    public mutating func record(pitch: UInt8, clef: Clef, missed: Bool) {
        var record = records[key(pitch, clef)] ?? Record()
        record.attempts = record.attempts * Self.memory + 1
        record.misses = record.misses * Self.memory + (missed ? 1 : 0)
        records[key(pitch, clef)] = record
    }

    /// The recent share of this note's prompts that went wrong, 0 if it was never missed.
    public func missRate(pitch: UInt8, clef: Clef) -> Double {
        guard let record = records[key(pitch, clef)] else { return 0 }
        return record.misses / (record.attempts + Self.priorAttempts)
    }

    /// The share of prompts each of `pitches` should get, in the same order; they add up to 1.
    public func shares(of pitches: [UInt8], clef: Clef) -> [Double] {
        let boosts = pitches.map { Self.maxBoost * missRate(pitch: $0, clef: clef) }
        let count = Double(pitches.count)
        let boostTotal = boosts.reduce(0, +)
        let scale = boostTotal > count ? count / boostTotal : 1
        let total = count + boostTotal * scale
        return boosts.map { (1 + $0 * scale) / total }
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
