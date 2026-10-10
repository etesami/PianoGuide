import PianoCore
import SwiftUI
import UniformTypeIdentifiers

/// Sheet listing the bundled samples (with category folders) and imported songs. Tap a song to practise it,
/// swipe to delete an imported one, or import `.mid` files from the Files app.
/// Songs played to the end at least once get a green check; songs with many recent wrong notes are tinted orange
/// as difficult (`SongProgress`). The song open now has a play icon.
/// The user can mark a song hard or interesting (swipe right or long-press); marked songs are also listed in
/// "Marked" at the top, to find them again later.
struct SongLibraryView: View {
    @ObservedObject var library: SongLibrary
    var current: SongLibrary.Entry?
    var onPick: (SongLibrary.Entry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            List {
                if !library.marked.isEmpty {
                    Section("Marked") {
                        ForEach(library.marked) { row($0) }
                    }
                }
                Section("Samples") {
                    ForEach(library.categories) { category in
                        NavigationLink {
                            List { ForEach(category.songs) { row($0) } }
                                .navigationTitle(category.name)
                        } label: {
                            HStack {
                                Label(category.name, systemImage: "folder")
                                Spacer()
                                folderSummary(category.songs)
                                if category.songs.contains(where: { $0 == current }) {
                                    Image(systemName: "play.fill").foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                    ForEach(library.samples) { row($0) }
                }
                Section {
                    if library.imported.isEmpty {
                        Text("No songs yet. Tap Import to add .mid files from the Files app.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(library.imported) { row($0) }
                        .onDelete { offsets in
                            offsets.map { library.imported[$0] }.forEach(library.delete)
                        }
                } header: {
                    Text("My Songs")
                }
            }
            .navigationTitle("Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showImporter = true } label: { Label("Import", systemImage: "square.and.arrow.down") }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.midi], allowsMultipleSelection: true,
                          onCompletion: importFiles)
            .alert("Could not import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func row(_ entry: SongLibrary.Entry) -> some View {
        let progress = self.progress(entry)
        return Button {
            onPick(entry)
            dismiss()
        } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                        if let detail = Self.detail(progress) {
                            Text(detail).font(.caption)
                                .foregroundColor(progress.isDifficult ? .orange : .secondary)
                        }
                    }
                } icon: {
                    Image(systemName: progress.isCompleted ? "checkmark.circle.fill" : "music.note")
                        .foregroundColor(progress.isCompleted ? .green : .accentColor)
                }
                Spacer()
                if let mark = progress.mark {
                    Image(systemName: mark.systemImage).foregroundColor(mark.color)
                }
                if progress.isDifficult {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                }
                if entry == current { Image(systemName: "play.fill").foregroundColor(.accentColor) }
            }
        }
        .foregroundColor(.primary)
        .listRowBackground(progress.isDifficult ? Color.orange.opacity(0.15) : nil)
        .swipeActions(edge: .leading) {
            ForEach(SongMark.allCases, id: \.self) { mark in
                Button {
                    library.setMark(progress.mark == mark ? nil : mark, of: entry)
                } label: {
                    Label(progress.mark == mark ? "Unmark" : mark.title, systemImage: mark.systemImage)
                }
                .tint(mark.color)
            }
        }
        .contextMenu {
            SongMarkPicker(mark: Binding(get: { library.progress(of: entry).mark },
                                         set: { library.setMark($0, of: entry) }))
        }
    }

    private func progress(_ entry: SongLibrary.Entry) -> SongProgress { library.progress(of: entry) }

    /// "Completed 2× · 3 wrong notes", "Difficult · 7 wrong notes", or nil if never played.
    private static func detail(_ progress: SongProgress) -> String? {
        var parts: [String] = []
        if progress.isDifficult { parts.append("Difficult") }
        if progress.isCompleted { parts.append("Completed \(progress.timesCompleted)×") }
        if let mistakes = progress.mistakes { parts.append("\(mistakes) wrong note\(mistakes == 1 ? "" : "s")") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "3/10 completed", plus a warning if any song inside is difficult.
    @ViewBuilder private func folderSummary(_ songs: [SongLibrary.Entry]) -> some View {
        let done = songs.filter { progress($0).isCompleted }.count
        if done > 0 { Text("\(done)/\(songs.count) completed").font(.caption).foregroundColor(.secondary) }
        if songs.contains(where: { progress($0).isDifficult }) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var failures: [String] = []
            var last: SongLibrary.Entry?
            for url in urls {
                do { last = try library.importFile(from: url) }
                catch { failures.append("\(url.lastPathComponent): \(Self.describe(error))") }
            }
            if !failures.isEmpty {
                importError = failures.joined(separator: "\n")
            } else if urls.count == 1, let last {
                // A single import goes straight to practice.
                onPick(last)
                dismiss()
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    static func describe(_ error: Error) -> String {
        switch error as? MIDIFileParser.ParseError {
        case .notAMIDIFile?: return "not a MIDI file."
        case .unsupportedFormat(let f)?: return "MIDI format \(f) isn't supported."
        case .smpteTimingNotSupported?: return "SMPTE timing isn't supported."
        case .truncated?: return "the file is damaged or cut short."
        case nil: return error.localizedDescription
        }
    }
}

extension SongMark {
    var title: String {
        switch self {
        case .hard: return "Hard"
        case .interesting: return "Interesting"
        }
    }

    var systemImage: String {
        switch self {
        case .hard: return "flag.fill"
        case .interesting: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .hard: return .red
        case .interesting: return .yellow
        }
    }
}

/// Menu items to mark a song hard or interesting, or clear the mark. Used in the song list and the practice toolbar.
struct SongMarkPicker: View {
    @Binding var mark: SongMark?

    var body: some View {
        Picker("Mark", selection: $mark) {
            Text("No Mark").tag(SongMark?.none)
            ForEach(SongMark.allCases, id: \.self) { mark in
                Label(mark.title, systemImage: mark.systemImage).tag(SongMark?.some(mark))
            }
        }
        .pickerStyle(.inline)
    }
}
