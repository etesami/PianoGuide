import Foundation

/// A short lesson shown before a practice: what to pay attention to and learn while playing it.
/// It is read from a Markdown file next to the song with the same name ("Fingers 1 · Pairs.md" for
/// "Fingers 1 · Pairs.mid"). Only a small part of Markdown is used:
/// - `# Title` (the first one) is the note's title; later `#`/`##` lines are section headings,
/// - lines starting with `- ` or `* ` are bullet points,
/// - other lines are paragraphs (lines next to each other are joined; a blank line starts a new paragraph).
/// - a fenced block starting with ```` ```staff ```` is a short music example drawn on the grand staff
///   (see `StaffExample` for what goes inside).
/// Text can use inline Markdown (`**bold**`, `*italic*`); the app renders it.
public struct PracticeNote: Equatable, Sendable {
    public enum Block: Equatable, Sendable {
        case heading(String)
        case paragraph(String)
        case bullet(String)
        case staff(StaffExample)
        /// A staff block that couldn't be read, with the reason (shown in place of the staff).
        case invalidStaff(String)
    }

    public var title: String?
    public var blocks: [Block]

    public init(markdown: String) {
        var title: String?
        var blocks: [Block] = []
        var paragraph: [String] = []
        var staffLines: [String]?    // inside a ```staff block
        func endParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))) }
            paragraph = []
        }
        for raw in markdown.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let lines = staffLines {
                if line.hasPrefix("```") {
                    do { blocks.append(.staff(try StaffExample(lines.joined(separator: "\n")))) }
                    catch { blocks.append(.invalidStaff("\(error)")) }
                    staffLines = nil
                } else {
                    staffLines = lines + [line]
                }
            } else if line.hasPrefix("```staff") {
                endParagraph()
                staffLines = []
            } else if line.isEmpty {
                endParagraph()
            } else if line.hasPrefix("#") {
                endParagraph()
                let text = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                if title == nil, blocks.isEmpty, line.hasPrefix("# ") { title = text } else { blocks.append(.heading(text)) }
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                endParagraph()
                blocks.append(.bullet(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
            } else if case .bullet(let text)? = blocks.last, paragraph.isEmpty, raw.hasPrefix(" ") {
                // An indented line right after a bullet continues it.
                blocks[blocks.count - 1] = .bullet(text + " " + line)
            } else {
                paragraph.append(line)
            }
        }
        endParagraph()
        if staffLines != nil { blocks.append(.invalidStaff("staff block has no closing ```")) }
        self.title = title
        self.blocks = blocks
    }

    public var isEmpty: Bool { title == nil && blocks.isEmpty }
}

/// A few bars of music written by hand in a lesson note, one line per hand:
///
///     right: C4/1 E4/3 G4/5! C4/1:4
///     left: C3/5:4 r:4
///     time: 3/4
///     caption: C, E and G make the C chord
///
/// Each note is a name with an octave (`C4` = middle C, `F#3`), followed by optional `/finger` (1–5) and `!`
/// to highlight it (drawn blue). Notes joined with `+` are a chord (`C3/5+G3/1`). `:beats` after the note or chord
/// sets its length in quarter notes (default 1; `:4` whole, `:2` half, `:0.5` eighth); a `!` after it highlights
/// the whole note or chord (`C4/1:2!`). `r` is a rest (`r:2`).
/// Both hands start at the beginning; `time` defaults to 4/4.
public struct StaffExample: Equatable, Sendable {
    public var notes: [NoteEvent]
    /// Ids of the notes marked with `!`.
    public var highlighted: Set<Int>
    public var timeSignature: TimeSignature
    public var caption: String?

    public struct ParseError: Error, CustomStringConvertible {
        public var description: String
    }

    public init(_ text: String) throws {
        var notes: [NoteEvent] = []
        var highlightedNotes: [NoteEvent] = []
        var time = TimeSignature(beat: 0, numerator: 4, denominator: 4)
        var caption: String?
        for line in text.components(separatedBy: .newlines) where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let colon = line.firstIndex(of: ":") else { throw ParseError(description: "no \"name:\" in \"\(line)\"") }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "right", "left":
                let hand: Hand = key == "right" ? .right : .left
                var beat = 0.0
                for var token in value.split(separator: " ") {
                    // "!" after the length highlights the whole note or chord.
                    let highlightAll = token.hasSuffix("!") && token.contains(":")
                    if highlightAll { token = token.dropLast() }
                    let parts = token.split(separator: ":", omittingEmptySubsequences: false)
                    guard parts.count <= 2, let beats = parts.count == 2 ? Double(parts[1]) : 1, beats > 0 else {
                        throw ParseError(description: "bad length in \"\(token)\"")
                    }
                    if parts[0].lowercased() != "r" {
                        for part in parts[0].split(separator: "+") {
                            var part = Substring(part)
                            let highlight = part.hasSuffix("!")
                            if highlight { part = part.dropLast() }
                            let pieces = part.split(separator: "/")
                            guard (1...2).contains(pieces.count), let pitch = Self.pitch(pieces[0]) else {
                                throw ParseError(description: "can't read note \"\(part)\"")
                            }
                            var finger: Int?
                            if pieces.count == 2 {
                                guard let f = Int(pieces[1]), (1...5).contains(f) else {
                                    throw ParseError(description: "bad finger in \"\(part)\"")
                                }
                                finger = f
                            }
                            let note = NoteEvent(id: 0, pitch: pitch, startBeat: beat, durationBeats: beats,
                                                 velocity: 80, hand: hand, finger: finger)
                            notes.append(note)
                            if highlight || highlightAll { highlightedNotes.append(note) }
                        }
                    }
                    beat += beats
                }
            case "time":
                let parts = value.split(separator: "/").compactMap { Int($0) }
                guard parts.count == 2, parts[0] > 0, [1, 2, 4, 8, 16].contains(parts[1]) else {
                    throw ParseError(description: "bad time \"\(value)\"")
                }
                time = TimeSignature(beat: 0, numerator: parts[0], denominator: parts[1])
            case "caption":
                caption = value
            default:
                throw ParseError(description: "unknown line \"\(key):\"")
            }
        }
        guard !notes.isEmpty else { throw ParseError(description: "staff block has no notes") }
        let sorted = notes.sorted { ($0.startBeat, $0.pitch) < ($1.startBeat, $1.pitch) }
        self.notes = sorted.enumerated().map { i, n in
            NoteEvent(id: i, pitch: n.pitch, startBeat: n.startBeat, durationBeats: n.durationBeats,
                      velocity: n.velocity, hand: n.hand, finger: n.finger)
        }
        highlighted = Set(self.notes.filter { n in
            highlightedNotes.contains { $0.pitch == n.pitch && $0.startBeat == n.startBeat && $0.hand == n.hand }
        }.map(\.id))
        timeSignature = time
        self.caption = caption
    }

    public var song: Song {
        Song(title: "", timeSignatures: [timeSignature], notes: notes)
    }

    /// "C4" → 60, "F#3" → 54; nil if it isn't a note name with an octave.
    static func pitch(_ name: Substring) -> UInt8? {
        let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let first = name.first.map({ Character($0.uppercased()) }), let base = letters[first] else { return nil }
        var rest = name.dropFirst()
        var semitone = base
        if rest.first == "#" { semitone += 1; rest = rest.dropFirst() }
        guard let octave = Int(rest), (0...8).contains(octave) else { return nil }
        let pitch = (octave + 1) * 12 + semitone
        return (21...108).contains(pitch) ? UInt8(pitch) : nil
    }
}
