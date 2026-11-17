import Foundation

/// A guided path written as a plain-text plan file, so new paths need no code: the player imports the plan together with
/// the song's MIDI file, and the plan's pieces are cut from the song by bar numbers (`PathPiece`). The music itself never
/// has to be in the app. Format (see `PathPlans/README.md`):
///
///     # Two Hands Together              title
///     id: two-hands-setaregan           keeps progress across re-imports
///     song: Ghoghaye Setaregan          shown when the song file is missing (default: the file name)
///     file: Ghoghaye Setaregan.mid      the song file this plan is for
///     short: Setaregan                  start of every piece's title (default: the song)
///     time: 3/4                         the song's time signature
///     bars: 116                         the song's length in bars
///
///     Summary text (paragraphs).
///
///     ## Parts
///     Section 1: 3-10                   name: first-last score bar
///
///     ## Lesson: Meet the song
///     goal: What the lesson is for.
///     tip: One tip per line.
///
///     ### Listen                        a step
///     piece: Section 1
///     left: low notes                   optional: full (default), low notes, low note + chord
///     right: long notes                 optional: melody (default), long notes
///     play: listen 75%                  listen N% | wait [right|left|both] | timed [hand] N% | play along right|left N%
///     runs: 2                           good runs in a row to pass (default 1)
///     What to do, in one or more lines.
public struct PathPlan: Equatable, Sendable {
    public var id: String
    public var title: String
    public var songName: String
    public var fileName: String
    public var shortName: String
    public var summary: String
    public var numerator: Int
    public var denominator: Int
    public var bars: Int
    public var parts: [Part]
    public var lessons: [Lesson]

    public struct Part: Equatable, Sendable {
        public var name: String
        public var bars: ClosedRange<Int>
    }

    public struct Lesson: Equatable, Sendable {
        public var title: String
        public var goal: String
        public var tips: [String]
        public var steps: [Step]
    }

    public struct Step: Equatable, Sendable {
        public var title: String
        public var part: String
        public var left: PathPiece.Left
        public var right: PathPiece.Right
        public var mode: PathStep.Mode
        public var hand: Clef?
        public var speed: Double
        public var runs: Int
        public var instruction: String
    }

    public struct ParseError: Error, LocalizedError, Equatable {
        /// 1-based line in the plan file, or 0 for the whole file.
        public var line: Int
        public var message: String
        public var errorDescription: String? { line > 0 ? "Line \(line): \(message)" : message }
    }

    // MARK: Reading

    public init(text: String) throws {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        func fail(_ i: Int, _ message: String) -> ParseError { ParseError(line: i + 1, message: message) }
        /// "key: value" for a known key, else nil.
        func keyValue(_ line: String, _ keys: Set<String>) -> (String, String)? {
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let key = line[..<colon].lowercased()
            guard keys.contains(key) else { return nil }
            return (key, line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
        }

        var i = 0
        while i < lines.count, lines[i].isEmpty { i += 1 }
        guard i < lines.count, lines[i].hasPrefix("# ") else {
            throw ParseError(line: i + 1, message: "The plan must start with \"# Title\".")
        }
        title = String(lines[i].dropFirst(2)).trimmingCharacters(in: .whitespaces)
        i += 1

        // Header keys, then the summary, up to the first "## ".
        var header: [String: String] = [:]
        var summaryParagraphs: [[String]] = [[]]
        let headerKeys: Set<String> = ["id", "song", "file", "short", "time", "bars"]
        while i < lines.count, !lines[i].hasPrefix("## ") {
            let line = lines[i]
            if summaryParagraphs == [[]], let (key, value) = keyValue(line, headerKeys) {
                header[key] = value
            } else if line.isEmpty {
                if summaryParagraphs.last?.isEmpty == false { summaryParagraphs.append([]) }
            } else {
                summaryParagraphs[summaryParagraphs.count - 1].append(line)
            }
            i += 1
        }
        guard let id = header["id"], !id.isEmpty else { throw ParseError(line: 0, message: "Missing \"id:\".") }
        guard let file = header["file"], !file.isEmpty else { throw ParseError(line: 0, message: "Missing \"file:\".") }
        guard let time = header["time"], let slash = time.firstIndex(of: "/"),
              let num = Int(time[..<slash]), let den = Int(time[time.index(after: slash)...]), num > 0, den > 0 else {
            throw ParseError(line: 0, message: "Missing or unreadable \"time:\" (like 3/4).")
        }
        guard let barText = header["bars"], let barCount = Int(barText), barCount > 0 else {
            throw ParseError(line: 0, message: "Missing or unreadable \"bars:\".")
        }
        self.id = id
        fileName = file
        songName = header["song"] ?? (file as NSString).deletingPathExtension
        shortName = header["short"] ?? songName
        numerator = num
        denominator = den
        bars = barCount
        summary = summaryParagraphs.filter { !$0.isEmpty }.map { $0.joined(separator: " ") }.joined(separator: "\n\n")

        parts = []
        lessons = []
        var step: (line: Int, title: String, keys: [String: String], text: [String])?
        func finishStep() throws {
            guard let s = step else { return }
            step = nil
            guard !lessons.isEmpty else { throw fail(s.line, "A step must be inside a lesson.") }
            lessons[lessons.count - 1].steps.append(try Self.makeStep(s, parts: parts, fail: fail))
        }
        var section = ""
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("### ") {
                try finishStep()
                guard section == "lesson" else { throw fail(i, "A step (\"### …\") must be inside a lesson.") }
                step = (i, String(line.dropFirst(4)), [:], [])
            } else if line.hasPrefix("## ") {
                try finishStep()
                let heading = String(line.dropFirst(3))
                if heading.lowercased() == "parts" {
                    section = "parts"
                } else if heading.lowercased().hasPrefix("lesson:") {
                    section = "lesson"
                    let name = heading.dropFirst("lesson:".count).trimmingCharacters(in: .whitespaces)
                    lessons.append(Lesson(title: name, goal: "", tips: [], steps: []))
                } else {
                    throw fail(i, "Unknown heading \"\(heading)\": use \"## Parts\" or \"## Lesson: Name\".")
                }
            } else if line.isEmpty || line.hasPrefix("<!--") {
                // Blank lines and comments.
            } else if step != nil {
                if let (key, value) = keyValue(line, ["piece", "left", "right", "play", "runs"]), step!.text.isEmpty {
                    guard step!.keys[key] == nil else { throw fail(i, "\"\(key):\" given twice in this step.") }
                    step!.keys[key] = value
                } else {
                    step!.text.append(line)
                }
            } else if section == "parts" {
                guard let colon = line.lastIndex(of: ":") else { throw fail(i, "A part is \"Name: first-last\".") }
                let name = line[..<colon].trimmingCharacters(in: .whitespaces)
                let range = line[line.index(after: colon)...].replacingOccurrences(of: "–", with: "-")
                    .split(separator: "-").map { Int($0.trimmingCharacters(in: .whitespaces)) }
                guard !name.isEmpty, range.count == 2, let a = range[0], let b = range[1], 1 <= a, a <= b, b <= barCount else {
                    throw fail(i, "A part is \"Name: first-last\", with bars from 1 to \(barCount).")
                }
                guard !parts.contains(where: { $0.name == name }) else { throw fail(i, "Part \"\(name)\" is given twice.") }
                parts.append(Part(name: name, bars: a...b))
            } else if section == "lesson" {
                if let (key, value) = keyValue(line, ["goal", "tip"]) {
                    if key == "goal" { lessons[lessons.count - 1].goal = value } else { lessons[lessons.count - 1].tips.append(value) }
                } else {
                    throw fail(i, "Before the steps, a lesson has only \"goal:\" and \"tip:\" lines.")
                }
            } else {
                throw fail(i, "Unexpected line.")
            }
            i += 1
        }
        try finishStep()
        guard !lessons.isEmpty else { throw ParseError(line: 0, message: "The plan has no lessons.") }
        for lesson in lessons {
            guard !lesson.goal.isEmpty else { throw ParseError(line: 0, message: "Lesson \"\(lesson.title)\" has no \"goal:\".") }
            guard !lesson.steps.isEmpty else { throw ParseError(line: 0, message: "Lesson \"\(lesson.title)\" has no steps.") }
        }
    }

    private static func makeStep(_ s: (line: Int, title: String, keys: [String: String], text: [String]), parts: [Part],
                                 fail: (Int, String) -> ParseError) throws -> Step {
        guard let piece = s.keys["piece"] else { throw fail(s.line, "Step \"\(s.title)\" has no \"piece:\".") }
        guard parts.contains(where: { $0.name == piece }) else {
            throw fail(s.line, "Step \"\(s.title)\": no part called \"\(piece)\" in \"## Parts\".")
        }
        guard let left = PathPiece.Left(rawValue: s.keys["left"]?.lowercased() ?? "full") else {
            throw fail(s.line, "Step \"\(s.title)\": \"left:\" is full, low notes or low note + chord.")
        }
        guard let right = PathPiece.Right(rawValue: s.keys["right"]?.lowercased() ?? "melody") else {
            throw fail(s.line, "Step \"\(s.title)\": \"right:\" is melody or long notes.")
        }
        guard let play = s.keys["play"] else { throw fail(s.line, "Step \"\(s.title)\" has no \"play:\".") }
        var words = play.lowercased().split(separator: " ").map(String.init)
        var mode: PathStep.Mode
        switch words.first {
        case "listen": mode = .listen; words.removeFirst()
        case "wait": mode = .wait; words.removeFirst()
        case "timed": mode = .timed; words.removeFirst()
        case "play" where words.count > 1 && words[1] == "along": mode = .playAlong; words.removeFirst(2)
        default: throw fail(s.line, "Step \"\(s.title)\": \"play:\" starts with listen, wait, timed or play along.")
        }
        var hand: Clef?
        var speed = 1.0
        for word in words {
            switch word {
            case "right": hand = .treble
            case "left": hand = .bass
            case "both": hand = nil
            default:
                guard let percent = Double(word.hasSuffix("%") ? String(word.dropLast()) : word), percent > 0 else {
                    throw fail(s.line, "Step \"\(s.title)\": can't read \"\(word)\" in \"play:\".")
                }
                speed = percent / 100
            }
        }
        if mode == .playAlong, hand == nil { throw fail(s.line, "Step \"\(s.title)\": play along needs right or left.") }
        if mode == .listen, hand != nil { throw fail(s.line, "Step \"\(s.title)\": listen plays both hands.") }
        let runs = Int(s.keys["runs"] ?? "1") ?? 0
        guard runs >= 1 else { throw fail(s.line, "Step \"\(s.title)\": \"runs:\" is a number from 1.") }
        guard !s.text.isEmpty else { throw fail(s.line, "Step \"\(s.title)\" says nothing about what to do.") }
        return Step(title: s.title, part: piece, left: left, right: right, mode: mode, hand: hand, speed: speed, runs: runs,
                    instruction: s.text.joined(separator: " "))
    }

    // MARK: The song

    /// Nil when `song` is laid out as the plan expects (time signature, both hands, length), else why not.
    public func problem(with song: Song) -> String? {
        guard let time = song.timeSignatures.first, time.numerator == numerator, time.denominator == denominator else {
            return "It isn't in \(numerator)/\(denominator) time."
        }
        guard song.notes.contains(where: { $0.hand == .right }), song.notes.contains(where: { $0.hand == .left }) else {
            return "It needs two tracks: the right hand first, then the left hand."
        }
        // Notes are often written a little short, so the last bar is the one the last note ends in.
        let end = song.notes.map { $0.startBeat + $0.durationBeats }.max() ?? 0
        let songBars = Int((end / time.beatsPerBar).rounded(.up))
        guard songBars == bars else { return "It has \(songBars) bars; the plan is for \(bars)." }
        return nil
    }

    /// The path, with every piece cut from `song` (check it with `problem(with:)` first).
    public func path(with song: Song) -> GuidedPath {
        var pieces: [String: Song] = [:]
        func piece(_ step: Step) -> Song {
            let key = "\(step.part)|\(step.left.rawValue)|\(step.right.rawValue)"
            if let song = pieces[key] { return song }
            var variant: [String] = []
            if step.right != .melody { variant.append(step.right.rawValue) }
            if step.left != .full { variant.append(step.left.rawValue) }
            let title = ([shortName, step.part] + (variant.isEmpty ? [] : [variant.joined(separator: " + ")]))
                .joined(separator: " · ")
            let bars = parts.first { $0.name == step.part }!.bars
            let made = PathPiece.song(from: song, bars: bars, left: step.left, right: step.right, title: title)
            pieces[key] = made
            return made
        }
        let built = lessons.enumerated().map { n, lesson in
            PathLesson(id: "\(n + 1)", number: n + 1, title: lesson.title, goal: lesson.goal, tips: lesson.tips,
                       steps: lesson.steps.enumerated().map { i, step in
                           PathStep(id: "\(n + 1).\(i + 1)", title: step.title, instruction: step.instruction,
                                    song: piece(step), mode: step.mode, hand: step.hand, speed: step.speed, runs: step.runs)
                       })
        }
        return GuidedPath(id: id, title: title, summary: summary, lessons: built)
    }
}
