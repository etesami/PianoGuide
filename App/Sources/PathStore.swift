import Foundation
import PianoCore

/// Keeps the player's `PathProgress` for every guided path, saved in UserDefaults ("pathProgress", JSON keyed by path id),
/// and the song files that some paths are built from (imported by the player, copied to Application Support/PathSongs/<id>.mid).
final class PathStore: ObservableObject {
    @Published private(set) var progress: [String: PathProgress] = [:]
    /// Imported path songs, by `PathSongFile.id`.
    @Published private(set) var songs: [String: Song] = [:]
    /// Paths built from their song, by entry id (built once per import, so step ids and songs stay the same).
    private var built: [String: GuidedPath] = [:]
    private static let defaultsKey = "pathProgress"

    private static var songFolder: URL {
        URL.applicationSupportDirectory.appending(path: "PathSongs", directoryHint: .isDirectory)
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey) {
            progress = (try? JSONDecoder().decode([String: PathProgress].self, from: data)) ?? [:]
        }
        for entry in GuidedPath.entries {
            guard let file = entry.songFile, songs[file.id] == nil,
                  let data = try? Data(contentsOf: Self.url(of: file)),
                  let song = try? MIDIFileParser.parse(data) else { continue }
            songs[file.id] = song
        }
    }

    // MARK: Song files

    private static func url(of file: PathSongFile) -> URL { songFolder.appending(path: file.id + ".mid") }

    /// The path for `entry`, or nil while the song file it needs hasn't been imported.
    func path(for entry: PathEntry) -> GuidedPath? {
        if let path = built[entry.id] { return path }
        let path = entry.path(with: entry.songFile.flatMap { songs[$0.id] })
        built[entry.id] = path
        return path
    }

    enum ImportError: LocalizedError {
        case wrongSong(String, reason: String)
        var errorDescription: String? {
            switch self {
            case .wrongSong(let name, let reason): return "This doesn't look like the right file for \(name). \(reason)"
            }
        }
    }

    /// Checks `source` and keeps a copy for every path that uses `file`. Replaces an earlier import; progress is kept.
    func importSong(from source: URL, for file: PathSongFile) throws {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: source)
        let song = try MIDIFileParser.parse(data)
        if let reason = file.problem(with: song) { throw ImportError.wrongSong(file.songName, reason: reason) }
        try FileManager.default.createDirectory(at: Self.songFolder, withIntermediateDirectories: true)
        try data.write(to: Self.url(of: file), options: .atomic)
        songs[file.id] = song
        forgetBuilt(using: file)
    }

    /// Deletes the imported copy; the paths using it need an import again. Progress is kept.
    func removeSong(for file: PathSongFile) {
        try? FileManager.default.removeItem(at: Self.url(of: file))
        songs[file.id] = nil
        forgetBuilt(using: file)
    }

    private func forgetBuilt(using file: PathSongFile) {
        for entry in GuidedPath.entries where entry.songFile?.id == file.id { built[entry.id] = nil }
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
