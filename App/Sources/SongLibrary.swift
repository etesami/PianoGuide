import Foundation
import PianoCore

/// The songs the user can pick: bundled samples plus `.mid` files imported from the Files app.
/// Imported files are copied into the app's Documents/Songs folder, so they stay after the original moves.
final class SongLibrary: ObservableObject {
    struct Entry: Identifiable, Hashable {
        let url: URL
        let isSample: Bool
        var id: URL { url }
        var name: String { url.deletingPathExtension().lastPathComponent }
    }

    @Published private(set) var samples: [Entry] = []
    @Published private(set) var imported: [Entry] = []

    private let folder: URL

    init() {
        folder = URL.documentsDirectory.appending(path: "Songs", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        samples = (Bundle.main.urls(forResourcesWithExtension: "mid", subdirectory: "SampleSongs") ?? [])
            .map { Entry(url: $0, isSample: true) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        imported = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["mid", "midi"].contains($0.pathExtension.lowercased()) }
            .map { Entry(url: $0, isSample: false) }
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
