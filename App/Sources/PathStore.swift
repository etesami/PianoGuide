import Foundation
import PianoCore

/// Keeps the player's `PathProgress` for every guided path, saved in UserDefaults ("pathProgress", JSON keyed by path id),
/// and the paths the player imported: plan files (`PathPlan`, Application Support/PathPlans/<id>.md) and the song files they
/// are built from (Application Support/PathSongs/<file name from the plan>). An imported path shows once both are in place.
final class PathStore: ObservableObject {
    @Published private(set) var progress: [String: PathProgress] = [:]
    /// Imported plans, by title.
    @Published private(set) var plans: [PathPlan] = []
    /// Imported songs, by the file name the plans use.
    @Published private(set) var songs: [String: Song] = [:]
    /// Paths built from a plan and its song, by plan id (built once per import, so step ids and songs stay the same).
    private var built: [String: GuidedPath] = [:]
    private static let defaultsKey = "pathProgress"

    private static let planFolder = URL.applicationSupportDirectory.appending(path: "PathPlans", directoryHint: .isDirectory)
    private static let songFolder = URL.applicationSupportDirectory.appending(path: "PathSongs", directoryHint: .isDirectory)

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey) {
            progress = (try? JSONDecoder().decode([String: PathProgress].self, from: data)) ?? [:]
        }
        let fm = FileManager.default
        for url in (try? fm.contentsOfDirectory(at: Self.planFolder, includingPropertiesForKeys: nil)) ?? [] {
            if let text = try? String(contentsOf: url, encoding: .utf8), let plan = try? PathPlan(text: text) { plans.append(plan) }
        }
        plans.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        for url in (try? fm.contentsOfDirectory(at: Self.songFolder, includingPropertiesForKeys: nil)) ?? [] {
            if let data = try? Data(contentsOf: url), let song = try? MIDIFileParser.parse(data) {
                songs[url.lastPathComponent] = song
            }
        }
    }

    // MARK: Paths

    /// The paths to show: the built-in ones, then each imported plan whose song is in place.
    var paths: [GuidedPath] { GuidedPath.builtIn + plans.compactMap(path(for:)) }

    /// Imported plans still waiting for their song file.
    var plansNeedingSong: [PathPlan] { plans.filter { path(for: $0) == nil } }

    func isImported(_ path: GuidedPath) -> Bool { plans.contains { $0.id == path.id } }

    private func path(for plan: PathPlan) -> GuidedPath? {
        if let path = built[plan.id] { return path }
        guard let song = songs[plan.fileName], plan.problem(with: song) == nil else { return nil }
        let path = plan.path(with: song)
        built[plan.id] = path
        return path
    }

    // MARK: Importing

    /// Imports plan files (.md, .txt) and song files (.mid). Plans go first, so a plan and its song can come in one go.
    /// A song is kept under the name its plan uses: the plan naming the file, else a plan still waiting for a song that it
    /// fits. Returns one line per file: what happened, and whether it went well.
    func importFiles(_ urls: [URL]) -> [(text: String, good: Bool)] {
        let isSong = { (url: URL) in ["mid", "midi"].contains(url.pathExtension.lowercased()) }
        var report: [(String, Bool)] = []
        for url in urls.filter({ !isSong($0) }) + urls.filter(isSong) {
            let name = url.lastPathComponent
            do {
                let data = try read(url)
                report.append(isSong(url) ? try importSong(data, name: name) : try importPlan(data, name: name))
            } catch let error as PathPlan.ParseError {
                report.append(("\(name): \(error.errorDescription ?? "")", false))
            } catch {
                report.append(("\(name): " + SongLibraryView.describe(error), false))
            }
        }
        return report
    }

    private func read(_ url: URL) throws -> Data {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }

    private func importPlan(_ data: Data, name: String) throws -> (String, Bool) {
        let plan = try PathPlan(text: String(decoding: data, as: UTF8.self))
        try FileManager.default.createDirectory(at: Self.planFolder, withIntermediateDirectories: true)
        try data.write(to: Self.planFolder.appending(path: plan.id + ".md"), options: .atomic)
        let replaced = plans.contains { $0.id == plan.id }
        plans.removeAll { $0.id == plan.id }
        plans.append(plan)
        plans.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        built[plan.id] = nil
        if path(for: plan) != nil { return ("\(replaced ? "Updated" : "Added") \"\(plan.title)\".", true) }
        return ("\(replaced ? "Updated" : "Added") \"\(plan.title)\". Now import its song file, \(plan.fileName).", true)
    }

    private func importSong(_ data: Data, name: String) throws -> (String, Bool) {
        let song = try MIDIFileParser.parse(data)
        let named = plans.filter { $0.fileName == name }
        let target: String
        if let plan = named.first {
            if let problem = plan.problem(with: song) {
                return ("\(name) doesn't fit \"\(plan.title)\": \(problem)", false)
            }
            target = name
        } else if let plan = plansNeedingSong.first(where: { $0.problem(with: song) == nil }) {
            target = plan.fileName
        } else {
            return ("\(name): no imported path uses this song. Import its plan file first, or both together.", false)
        }
        try FileManager.default.createDirectory(at: Self.songFolder, withIntermediateDirectories: true)
        try data.write(to: Self.songFolder.appending(path: target), options: .atomic)
        songs[target] = song
        let opened = plans.filter { $0.fileName == target }
        for plan in opened { built[plan.id] = nil }
        return ("Song added for " + opened.map { "\"\($0.title)\"" }.joined(separator: ", ") + ".", true)
    }

    /// Removes an imported path's plan, and its song file when no other plan uses it. Progress is kept, so importing it
    /// again carries on where it was.
    func remove(_ path: GuidedPath) {
        guard let plan = plans.first(where: { $0.id == path.id }) else { return }
        try? FileManager.default.removeItem(at: Self.planFolder.appending(path: plan.id + ".md"))
        plans.removeAll { $0.id == plan.id }
        built[plan.id] = nil
        if !plans.contains(where: { $0.fileName == plan.fileName }) {
            try? FileManager.default.removeItem(at: Self.songFolder.appending(path: plan.fileName))
            songs[plan.fileName] = nil
        }
    }

    func progress(of path: GuidedPath) -> PathProgress { progress[path.id] ?? PathProgress() }

    @discardableResult
    func record(_ run: PathStep.Run, of step: PathStep, in path: GuidedPath) -> PathProgress.Outcome {
        let outcome = progress[path.id, default: PathProgress()].record(run, of: step, in: path)
        save()
        return outcome
    }

    /// Forgets everything passed in `path`, so it starts again at the first step.
    func reset(_ path: GuidedPath) {
        progress[path.id] = nil
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}

/// The path step open on the practice screen.
struct PathSelection: Equatable {
    let path: GuidedPath
    let step: PathStep

    static func == (a: PathSelection, b: PathSelection) -> Bool { a.path.id == b.path.id && a.step.id == b.step.id }

    var lesson: PathLesson? { path.lesson(of: step) }
    /// 1-based place of the step in its lesson.
    var numberInLesson: Int { (lesson?.steps.firstIndex { $0.id == step.id } ?? 0) + 1 }
}
