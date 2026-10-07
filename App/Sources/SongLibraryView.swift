import PianoCore
import SwiftUI
import UniformTypeIdentifiers

/// Sheet listing the bundled samples and imported songs. Tap a song to practise it,
/// swipe to delete an imported one, or import `.mid` files from the Files app.
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
                Section("Samples") {
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
        Button {
            onPick(entry)
            dismiss()
        } label: {
            HStack {
                Label(entry.name, systemImage: "music.note")
                Spacer()
                if entry == current { Image(systemName: "checkmark").foregroundColor(.accentColor) }
            }
        }
        .foregroundColor(.primary)
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
