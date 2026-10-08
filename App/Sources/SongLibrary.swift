import Foundation
import PianoCore

/// The songs the user can pick: bundled samples plus `.mid` files imported from the Files app.
/// Bundled samples in a subfolder of SampleSongs belong to that category (e.g. "Intermediate III").
/// Imported files are copied into the app's Documents/Songs folder, so they stay after the original moves.
/// Also keeps each song's `SongProgress` (completed / difficult), saved in UserDefaults.
final class SongLibrary: ObservableObject {
    struct Category: Identifiable, Hashable {
        let name: String
        let songs: [Entry]
        var id: String { name }
    }

    struct Entry: Identifiable, Hashable {
        let url: URL
        let isSample: Bool
        var id: URL { url }
        var name: String { url.deletingPathExtension().lastPathComponent }
        /// Stable across launches: the path inside SampleSongs ("Intermediate III/x.mid"), or "My Songs/x.mid".
        var progressKey: String {
            isSample ? url.pathComponents.drop { $0 != "SampleSongs" }.dropFirst().joined(separator: "/")
                     : "My Songs/" + url.lastPathComponent
        }
    }

    /// Samples outside any category folder.
    @Published private(set) var samples: [Entry] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var imported: [Entry] = []
    @Published private(set) var progress: [String: SongProgress] = [:]
    private static let progressDefaultsKey = "songProgress"

    private let folder: URL

    init() {
        folder = URL.documentsDirectory.appending(path: "Songs", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = UserDefaults.standard.data(forKey: Self.progressDefaultsKey) {
            progress = (try? JSONDecoder().decode([String: SongProgress].self, from: data)) ?? [:]
        }
        reload()
    }

    func progress(of entry: Entry) -> SongProgress { progress[entry.progressKey] ?? SongProgress() }

    func updateProgress(of entry: Entry, _ change: (inout SongProgress) -> Void) {
        change(&progress[entry.progressKey, default: SongProgress()])
        saveProgress()
    }

    private func saveProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: Self.progressDefaultsKey)
        }
    }

    func reload() {
        let samplesFolder = Bundle.main.resourceURL?.appending(path: "SampleSongs", directoryHint: .isDirectory)
        samples = samplesFolder.map { Self.songs(in: $0, isSample: true) } ?? []
        categories = (samplesFolder.flatMap { try? FileManager.default.contentsOfDirectory(
                at: $0, includingPropertiesForKeys: [.isDirectoryKey]) } ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { Category(name: $0.lastPathComponent, songs: Self.songs(in: $0, isSample: true)) }
            .filter { !$0.songs.isEmpty }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        imported = Self.songs(in: folder, isSample: false)
    }

    /// All samples, in categories or not.
    var allSamples: [Entry] { samples + categories.flatMap(\.songs) }

    private static func songs(in folder: URL, isSample: Bool) -> [Entry] {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["mid", "midi"].contains($0.pathExtension.lowercased()) }
            .map { Entry(url: $0, isSample: isSample) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Checks that `source` parses, then copies it into the library. Returns the new entry.
    /// A file with the same name gets a number added ("Song 2.mid").
    @discardableResult
    func importFile(from source: URL) throws -> Entry {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: source)
        _ = try Self.parse(data, name: source.deletingPathExtension().lastPathComponent)

        let base = source.deletingPathExtension().lastPathComponent
        var target = folder.appending(path: base + ".mid")
        var n = 2
        while FileManager.default.fileExists(atPath: target.path) {
            target = folder.appending(path: "\(base) \(n).mid")
            n += 1
        }
        try data.write(to: target)
        reload()
        return Entry(url: target, isSample: false)
    }

    func delete(_ entry: Entry) {
        guard !entry.isSample else { return }
        try? FileManager.default.removeItem(at: entry.url)
        // A later import with the same name is a new song.
        progress[entry.progressKey] = nil
        saveProgress()
        reload()
    }

    func load(_ entry: Entry) throws -> Song {
        var song = try Self.parse(Data(contentsOf: entry.url), name: entry.name)
        // Track names in downloaded files are often just "Piano"; the file name is a better title.
        if !entry.isSample { song.title = entry.name }
        return song
    }

    enum LoadError: LocalizedError {
        case noNotes(String)
        var errorDescription: String? {
            switch self {
            case .noNotes(let name): return "\"\(name)\" has no notes to play."
            }
        }
    }

    private static func parse(_ data: Data, name: String) throws -> Song {
        let song = try MIDIFileParser.parse(data, title: name)
        guard !song.notes.isEmpty else { throw LoadError.noNotes(name) }
        return song
    }
}
