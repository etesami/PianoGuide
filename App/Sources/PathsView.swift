import PianoCore
import SwiftUI
import UniformTypeIdentifiers

/// Sheet with the guided paths. With a single path it opens straight on that path's lessons. With several, it opens on
/// the path of the step that is open (if any), so "Steps" during a step comes back to where the player is.
/// A path built from a song file shows an import screen until the player has imported that file.
struct PathsView: View {
    @ObservedObject var store: PathStore
    var active: PathSelection?
    var onStart: (PathStep, GuidedPath) -> Void
    @Environment(\.dismiss) private var dismiss
    /// Ids of the paths pushed on the navigation stack.
    @State private var shown: [String]

    init(store: PathStore, active: PathSelection?, onStart: @escaping (PathStep, GuidedPath) -> Void) {
        self.store = store
        self.active = active
        self.onStart = onStart
        _shown = State(initialValue: GuidedPath.entries.count > 1 ? active.map { [$0.path.id] } ?? [] : [])
    }

    var body: some View {
        NavigationStack(path: $shown) {
            Group {
                if GuidedPath.entries.count == 1, let entry = GuidedPath.entries.first {
                    entryView(entry)
                } else {
                    List(GuidedPath.entries) { entry in
                        NavigationLink(value: entry.id) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                if let path = store.path(for: entry) {
                                    Text("\(store.progress(of: path).passedCount(in: path)) of \(path.steps.count) steps passed")
                                        .font(.caption).foregroundColor(.secondary)
                                } else if let file = entry.songFile {
                                    Label("Needs your song file: \(file.songName)", systemImage: "square.and.arrow.down")
                                        .font(.caption).foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .navigationTitle("Paths")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { id in
                if let entry = GuidedPath.entries.first(where: { $0.id == id }) { entryView(entry) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    @ViewBuilder private func entryView(_ entry: PathEntry) -> some View {
        if let path = store.path(for: entry) {
            PathDetailView(store: store, path: path, songFile: entry.songFile, active: active, onStart: start)
        } else if let file = entry.songFile {
            PathSongImportView(store: store, entry: entry, file: file)
        }
    }

    private func start(_ step: PathStep, _ path: GuidedPath) {
        onStart(step, path)
        dismiss()
    }
}

/// Shown for a path whose song file hasn't been imported yet: what the path is, which file it needs, and an import button.
struct PathSongImportView: View {
    @ObservedObject var store: PathStore
    let entry: PathEntry
    let file: PathSongFile
    @State private var showImporter = false
    @State private var error: String?

    var body: some View {
        List {
            Section { Text(entry.summary).font(.callout) }
            Section {
                Label("This path is built from your own copy of \(file.songName). The song isn't included in the app.",
                      systemImage: "music.note")
                Text(file.hint).font(.callout).foregroundColor(.secondary)
                Button { showImporter = true } label: {
                    Label("Import Song File…", systemImage: "square.and.arrow.down")
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
                }
            } footer: {
                Text("You import it once; every path that uses it opens.")
            }
        }
        .navigationTitle(entry.title)
        .pathSongImporter(isPresented: $showImporter, store: store, file: file, error: $error)
    }
}

extension View {
    /// The Files picker for a path's song file; puts the reason in `error` if the file can't be used.
    func pathSongImporter(isPresented: Binding<Bool>, store: PathStore, file: PathSongFile,
                          error problem: Binding<String?>) -> some View {
        fileImporter(isPresented: isPresented, allowedContentTypes: [.midi]) { result in
            switch result {
            case .success(let url):
                do {
                    try store.importSong(from: url, for: file)
                    problem.wrappedValue = nil
                } catch {
                    problem.wrappedValue = (error as? PathStore.ImportError)?.errorDescription
                        ?? "\(url.lastPathComponent): " + SongLibraryView.describe(error)
                }
            case .failure(let failure):
                problem.wrappedValue = failure.localizedDescription
            }
        }
    }
}

/// One path: its lessons in order, each with its goal, tips and steps. Passed steps have a green check, the next one
/// to pass a play icon, later ones a lock (they can't be opened yet). Passed steps can be played again.
struct PathDetailView: View {
    @ObservedObject var store: PathStore
    let path: GuidedPath
    /// The imported file the path is built from, or nil for a built-in path.
    var songFile: PathSongFile?
    var active: PathSelection?
    var onStart: (PathStep, GuidedPath) -> Void
    @State private var confirmReset = false
    @State private var confirmRemove = false
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        let progress = store.progress(of: path)
        let current = progress.current(in: path)
        ScrollViewReader { proxy in
        List {
            Section {
                Text(path.summary).font(.callout)
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(progress.passedCount(in: path)), total: Double(path.steps.count))
                        .tint(.green)
                    Text("\(progress.passedCount(in: path)) of \(path.steps.count) steps passed")
                        .font(.caption).foregroundColor(.secondary)
                }
                if let current {
                    Button { onStart(current, path) } label: {
                        Label("Continue: lesson \(path.lesson(of: current)?.number ?? 0), \(current.title)",
                              systemImage: "play.fill")
                    }
                } else {
                    Label("Path finished. Well done!", systemImage: "star.fill").foregroundColor(.green)
                }
            }
            ForEach(path.lessons) { lesson in
                Section {
                    Text(lesson.goal).font(.callout)
                    if !lesson.tips.isEmpty {
                        DisclosureGroup("Tips") {
                            ForEach(lesson.tips, id: \.self) { tip in
                                Label(tip, systemImage: "lightbulb").font(.callout)
                            }
                        }
                    }
                    ForEach(lesson.steps) { step in
                        stepRow(step, progress: progress, isCurrent: step.id == current?.id)
                            .id(step.id)
                    }
                } header: {
                    HStack {
                        Text("Lesson \(lesson.number) · \(lesson.title)")
                        Spacer()
                        if lesson.steps.allSatisfy(progress.isPassed) {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Show where the player is: the step open on the practice screen, else the next one to pass.
            let target = active?.path.id == path.id ? active?.step.id : current?.id
            guard let target else { return }
            // The list needs a moment to lay out its rows before it can scroll to one.
            DispatchQueue.main.async { proxy.scrollTo(target, anchor: .center) }
        }
        }
        .navigationTitle(path.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) { confirmReset = true } label: {
                        Label("Start Over…", systemImage: "arrow.counterclockwise")
                    }
                    if songFile != nil {
                        Button { showImporter = true } label: {
                            Label("Replace Song File…", systemImage: "square.and.arrow.down")
                        }
                        Button(role: .destructive) { confirmRemove = true } label: {
                            Label("Remove Song File…", systemImage: "trash")
                        }
                    }
                } label: { Label("More", systemImage: "ellipsis.circle") }
            }
        }
        .confirmationDialog("Start \"\(path.title)\" over?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Start Over", role: .destructive) { store.reset(path) }
        } message: {
            Text("Every step goes back to locked, except the first.")
        }
        .confirmationDialog("Remove the song file?", isPresented: $confirmRemove, titleVisibility: .visible) {
            if let songFile { Button("Remove", role: .destructive) { store.removeSong(for: songFile) } }
        } message: {
            Text("The paths that use it close until you import it again. Your progress is kept; the original file is not touched.")
        }
        .modifier(OptionalSongImporter(isPresented: $showImporter, store: store, file: songFile, error: $importError))
        .alert("Can't use this file", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private func stepRow(_ step: PathStep, progress: PathProgress, isCurrent: Bool) -> some View {
        let passed = progress.isPassed(step)
        let open = progress.isOpen(step, in: path)
        return Button { onStart(step, path) } label: {
            HStack {
                Image(systemName: passed ? "checkmark.circle.fill" : isCurrent ? "play.circle.fill" : "lock.fill")
                    .foregroundColor(passed ? .green : isCurrent ? .accentColor : .secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title).foregroundColor(open ? .primary : .secondary)
                    Text(step.settingsSummary + " · " + Self.runsText(step, progress: progress))
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if active?.step.id == step.id, active?.path.id == path.id {
                    Text("Open").font(.caption).foregroundColor(.accentColor)
                }
            }
        }
        .disabled(!open)
    }

    /// "1 good run", "2 good runs in a row (1 so far)".
    static func runsText(_ step: PathStep, progress: PathProgress) -> String {
        if step.mode == .listen { return "listen to the end" }
        let base = step.runs == 1 ? "1 good run" : "\(step.runs) good runs in a row"
        let streak = progress.streak(of: step)
        return !progress.isPassed(step) && streak > 0 ? base + " (\(streak) so far)" : base
    }
}

/// Shown over the practice screen while a path step is open: where it is in the path, what to do, how far along it is,
/// and a warning (with a fix) when the screen's settings would not count for the step.
/// `compact` (a short screen, e.g. iPad landscape) puts it on one line; the instruction is behind an info button.
struct PathStepBanner: View {
    let selection: PathSelection
    var compact = false
    let progress: PathProgress
    /// The practice screen is set up as the step asks (mode, hand, speed).
    let settingsMatch: Bool
    var onUseSettings: () -> Void
    var onNext: (() -> Void)?
    var onShowPath: () -> Void
    var onLeave: () -> Void
    @State private var showInfo = false

    private var step: PathStep { selection.step }
    private var passed: Bool { progress.isPassed(step) }
    private var place: String {
        "Lesson \(selection.lesson?.number ?? 0) · \(selection.lesson?.title ?? "") · step \(selection.numberInLesson) of \(selection.lesson?.steps.count ?? 0)"
    }
    private var toPass: String {
        "To pass: " + PathDetailView.runsText(step, progress: progress)
            + (step.mode == .listen ? "" : ", with mistakes on 10% of the notes or fewer")
    }

    var body: some View {
        Group {
            if compact { compactBody } else { fullBody }
        }
        .padding(compact ? 8 : 12)
        .background(RoundedRectangle(cornerRadius: 12).fill((passed ? Color.green : Color.accentColor).opacity(0.1)))
    }

    private var icon: some View {
        Image(systemName: passed ? "checkmark.circle.fill" : "figure.walk")
            .font(compact ? .title3 : .title2)
            .foregroundColor(passed ? .green : .accentColor)
    }

    private var fullBody: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 4) {
                Text(place).font(.caption).foregroundColor(.secondary)
                Text("\(step.title): \(step.settingsSummary)").font(.headline)
                Text(step.instruction).font(.subheadline)
                status
            }
            Spacer(minLength: 0)
            buttons
        }
    }

    private var compactBody: some View {
        HStack(spacing: 10) {
            icon
            Text("L\(selection.lesson?.number ?? 0).\(selection.numberInLesson) · \(step.title): \(step.settingsSummary)")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Button { showInfo = true } label: { Label("What to Do", systemImage: "info.circle") }
                .labelStyle(.iconOnly)
                .popover(isPresented: $showInfo) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(place).font(.caption).foregroundColor(.secondary)
                        Text("\(step.title): \(step.settingsSummary)").font(.headline)
                        Text(step.instruction)
                        if !passed { Text(toPass).font(.subheadline).foregroundColor(.secondary) }
                    }
                    .padding()
                    .frame(width: 380)
                }
            if passed {
                Text("Passed").font(.subheadline.bold()).foregroundColor(.green)
            } else if !settingsMatch {
                Button(action: onUseSettings) {
                    Label("Use Step Settings", systemImage: "exclamationmark.triangle.fill")
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.orange)
            } else {
                Text("\(progress.streak(of: step)) of \(step.runs)").font(.subheadline).foregroundColor(.secondary)
                    .opacity(step.mode == .listen ? 0 : 1)
            }
            Spacer(minLength: 0)
            buttons
        }
    }

    @ViewBuilder private var status: some View {
        if passed {
            Text("Passed").font(.subheadline.bold()).foregroundColor(.green)
        } else if settingsMatch {
            Text(toPass).font(.subheadline).foregroundColor(.secondary)
        } else {
            HStack {
                Label("These settings don't count for this step", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline).foregroundColor(.orange)
                Button("Use Step Settings", action: onUseSettings).buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            if let onNext {
                Button(action: onNext) { Label("Next Step", systemImage: "arrow.right") }
                    .buttonStyle(.borderedProminent).tint(.green)
            }
            Button(action: onShowPath) { Label("Steps", systemImage: "list.bullet") }
                .buttonStyle(.bordered)
            Button(action: onLeave) { Label("Leave Path", systemImage: "xmark") }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
        }
        .controlSize(compact ? .small : .regular)
    }
}

/// `pathSongImporter` when there is a file to import.
private struct OptionalSongImporter: ViewModifier {
    @Binding var isPresented: Bool
    let store: PathStore
    let file: PathSongFile?
    @Binding var error: String?

    func body(content: Content) -> some View {
        if let file {
            content.pathSongImporter(isPresented: $isPresented, store: store, file: file, error: $error)
        } else {
            content
        }
    }
}
