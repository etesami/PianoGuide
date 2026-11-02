import Foundation

/// The shape of a piece, or of one hand of it: which stretches of bars come back later (like A A′ B A).
/// MIDI files have no repeat signs, so this is worked out from the notes. Two bars match when they have the same
/// pitches at the same places in the bar. A repeat in another key is not found.
public struct SongForm: Equatable, Sendable {
    public struct Section: Equatable, Sendable {
        /// "A", or "A′" when some of its bars differ from the first time; "–" for rests.
        public var label: String
        /// 0 for A, 1 for B, …; A and A′ share it. Negative for rests.
        public var letterIndex: Int
        /// Bar indexes (0 = first bar).
        public var bars: Range<Int>
        /// For a section that came before: where it first appeared.
        public var firstAppearance: Int?
        /// For a section's first appearance: the bars where it starts again later.
        public var returnsAt: [Int] = []
        /// For a section that came before: the bars that differ from the first time.
        public var changedBars: [Int] = []
        /// One bar played over and over, rather than a longer stretch.
        public var isOneBarPattern = false

        public var isRests: Bool { letterIndex < 0 }

        /// One line telling what to notice about this section. Bars are counted from 1, as on the screen.
        public var note: String {
            if isRests { return "Rests" }
            let comesBack = "\(returnsAt.count == 1 ? "bar" : "bars") \(SongForm.list(returnsAt))"
            if isOneBarPattern {
                if let firstAppearance { return "Same bar as bar \(firstAppearance + 1), played \(bars.count) times" }
                return "One bar played \(bars.count) times" + (returnsAt.isEmpty ? "" : ", comes back at \(comesBack)")
            }
            if let firstAppearance {
                guard !changedBars.isEmpty else { return "Same as bar \(firstAppearance + 1)" }
                let changed = SongForm.list(changedBars)
                return "Like bar \(firstAppearance + 1), but \(changedBars.count == 1 ? "bar \(changed) is" : "bars \(changed) are") different"
            }
            return returnsAt.isEmpty ? "Plays once" : "Comes back at \(comesBack)"
        }
    }

    /// In playing order, covering every bar.
    public var sections: [Section]
    public var barCount: Int
    /// Bars that are new to the player: each first appearance (one for a one-bar pattern), plus the ones a near-repeat
    /// changes. Bars of rests don't count, so this is 0 when the hand has nothing to play.
    public var barsToLearn: Int

    public var hasRepeats: Bool { sections.contains { $0.firstAppearance != nil || $0.isOneBarPattern } }

    /// The form as one line: "A A′ B A".
    public var summary: String { sections.map(\.label).joined(separator: " ") }

    /// With `clef` set, only that hand's notes count; the bars stay those of the whole song, so bar numbers don't change.
    public init(song: Song, clef: Clef? = nil) {
        let bars = Self.barContents(of: song, clef: clef)
        var found = [Occurrence?](repeating: nil, count: bars.count)   // by first bar
        var claimed = [Bool](repeating: false, count: bars.count)
        while let group = Self.longestRepeat(in: bars, claimed: claimed) {
            for (i, occurrence) in group.enumerated() {
                claimed.replaceSubrange(occurrence.bars, with: repeatElement(true, count: occurrence.bars.count))
                found[occurrence.bars.lowerBound] = Occurrence(
                    bars: occurrence.bars, changed: occurrence.changed,
                    first: i == 0 ? nil : group[0].bars.lowerBound,
                    returns: i == 0 ? group.dropFirst().map(\.bars.lowerBound) : [])
            }
        }
        Self.claimOneBarPatterns(in: bars, found: &found, claimed: &claimed)

        // Walk through the piece; the bars nothing claimed form "plays once" or rests sections between the others.
        var sections: [Section] = []
        var letters: [Int: Int] = [:]   // first bar of a section's first appearance → its letter
        var nextLetter = 0
        var bar = 0
        while bar < bars.count {
            if let occurrence = found[bar] {
                let letter: Int
                if let first = occurrence.first, let known = letters[first] {
                    letter = known
                } else {
                    letter = nextLetter
                    letters[bar] = letter
                    nextLetter += 1
                }
                sections.append(Section(label: Self.name(letter) + (occurrence.changed.isEmpty ? "" : "′"),
                                        letterIndex: letter, bars: occurrence.bars, firstAppearance: occurrence.first,
                                        returnsAt: occurrence.returns, changedBars: occurrence.changed,
                                        isOneBarPattern: occurrence.isOneBarPattern))
                bar = occurrence.bars.upperBound
            } else {
                var end = bar + 1
                while end < bars.count, !claimed[end] { end += 1 }
                if bars[bar..<end].allSatisfy(\.isEmpty) {
                    sections.append(Section(label: "–", letterIndex: -1, bars: bar..<end))
                } else {
                    sections.append(Section(label: Self.name(nextLetter), letterIndex: nextLetter, bars: bar..<end))
                    nextLetter += 1
                }
                bar = end
            }
        }
        self.sections = sections
        barCount = bars.count
        barsToLearn = sections.reduce(0) { total, section in
            if section.isOneBarPattern { return total + (section.firstAppearance == nil ? 1 : 0) }
            if section.firstAppearance != nil { return total + section.changedBars.count }
            return total + bars[section.bars].filter { !$0.isEmpty }.count
        }
    }

    private struct Occurrence {
        var bars: Range<Int>
        var changed: [Int]
        var first: Int?
        var returns: [Int]
        var isOneBarPattern = false
    }

    /// What is played in each bar, as text that is equal for equal bars (empty for a bar of rests).
    private static func barContents(of song: Song, clef: Clef?) -> [String] {
        guard !song.notes.isEmpty else { return [] }
        let starts = song.barStartBeats
        var notes = [[String]](repeating: [], count: starts.count)
        for note in song.notes where clef == nil || StaffLayout.clef(for: note) == clef {
            let bar = song.barIndex(atBeat: note.startBeat)
            // In 48ths of a beat, finer than any written note, so rounding in the file doesn't split equal bars.
            let place = Int(((note.startBeat - starts[bar]) * 48).rounded())
            notes[bar].append("\(note.pitch)@\(place)")
        }
        return notes.map { $0.sorted().joined(separator: ",") }
    }

    /// The longest stretch of free bars that comes back, with all its appearances; the first one has no changes.
    /// Among equally long ones: the one that comes back most often, then the one with the fewest changes, then the earliest.
    /// A stretch of one bar over and over is left out: that is a one-bar pattern, not a section that comes back.
    private static func longestRepeat(in bars: [String], claimed: [Bool]) -> [(bars: Range<Int>, changed: [Int])]? {
        guard bars.count >= 4 else { return nil }
        for length in stride(from: bars.count / 2, through: 2, by: -1) {
            let isFree = { (start: Int) in !claimed[start..<(start + length)].contains(true) }
            var best: [(bars: Range<Int>, changed: [Int])]?
            var bestChanges = 0
            for start in 0...(bars.count - length) where isFree(start) && Set(bars[start..<(start + length)]).count > 1 {
                var group: [(bars: Range<Int>, changed: [Int])] = [(start..<(start + length), [])]
                var changes = 0
                var other = start + length
                while other + length <= bars.count {
                    if isFree(other), let changed = differences(bars, start, other, length) {
                        group.append((other..<(other + length), changed))
                        changes += changed.count
                        other += length
                    } else {
                        other += 1
                    }
                }
                guard group.count > 1 else { continue }
                if best == nil || group.count > best!.count || (group.count == best!.count && changes < bestChanges) {
                    best = group
                    bestChanges = changes
                }
            }
            if let best { return best }
        }
        return nil
    }

    /// Among the bars still free: the same played bar two or more times in a row. Runs of the same bar are one section coming back.
    private static func claimOneBarPatterns(in bars: [String], found: inout [Occurrence?], claimed: inout [Bool]) {
        var firstRun: [String: Int] = [:]
        var bar = 0
        while bar < bars.count {
            guard !claimed[bar], !bars[bar].isEmpty else { bar += 1; continue }
            var end = bar + 1
            while end < bars.count, !claimed[end], bars[end] == bars[bar] { end += 1 }
            if end - bar >= 2 {
                let first = firstRun[bars[bar]]
                found[bar] = Occurrence(bars: bar..<end, changed: [], first: first, returns: [], isOneBarPattern: true)
                if let first { found[first]?.returns.append(bar) } else { firstRun[bars[bar]] = bar }
                claimed.replaceSubrange(bar..<end, with: repeatElement(true, count: end - bar))
            }
            bar = end
        }
    }

    /// The bars of the stretch at `other` that differ from the one at `start`, or nil if it isn't a repeat: at most a quarter
    /// of its bars may differ, and at least two played bars must match (bars of rests alone don't make a repeat).
    private static func differences(_ bars: [String], _ start: Int, _ other: Int, _ length: Int) -> [Int]? {
        var changed: [Int] = []
        var matching = 0
        for i in 0..<length {
            if bars[start + i] != bars[other + i] {
                changed.append(other + i)
                if changed.count > length / 4 { return nil }
            } else if !bars[start + i].isEmpty {
                matching += 1
            }
        }
        return matching >= 2 ? changed : nil
    }

    /// A, B, … Z, then A2, B2, …
    private static func name(_ letter: Int) -> String {
        let name = String(UnicodeScalar(UInt8(65 + letter % 26)))
        return letter < 26 ? name : name + "\(letter / 26 + 1)"
    }

    /// Bar indexes as bar numbers in words: "5", "5 and 17", "5, 9 and 17".
    private static func list(_ bars: [Int]) -> String {
        let numbers = bars.map { String($0 + 1) }
        guard let last = numbers.last, numbers.count > 1 else { return numbers.first ?? "" }
        return numbers.dropLast().joined(separator: ", ") + " and " + last
    }
}
