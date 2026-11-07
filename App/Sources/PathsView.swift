import PianoCore
import SwiftUI

/// Sheet with the guided paths. With a single path it opens straight on that path's lessons.
struct PathsView: View {
    @ObservedObject var store: PathStore
    var active: PathSelection?
    var onStart: (PathStep, GuidedPath) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if GuidedPath.all.count == 1, let path = GuidedPath.all.first {
                    PathDetailView(store: store, path: path, active: active, onStart: start)
                } else {
                    List(GuidedPath.all) { path in
                        NavigationLink {
                            PathDetailView(store: store, path: path, active: active, onStart: start)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(path.title)
                                Text("\(store.progress(of: path).passedCount(in: path)) of \(path.steps.count) steps passed")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .navigationTitle("Paths")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func start(_ step: PathStep, _ path: GuidedPath) {
        onStart(step, path)
        dismiss()
    }
}

/// One path: its lessons in order, each with its goal, tips and steps. Passed steps have a green check, the next one
/// to pass a play icon, later ones a lock (they can't be opened yet). Passed steps can be played again.
struct PathDetailView: View {
    @ObservedObject var store: PathStore
    let path: GuidedPath
    var active: PathSelection?
    var onStart: (PathStep, GuidedPath) -> Void
    @State private var confirmReset = false

    var body: some View {
        let progress = store.progress(of: path)
        let current = progress.current(in: path)
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
        .navigationTitle(path.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) { confirmReset = true } label: {
                        Label("Start Over…", systemImage: "arrow.counterclockwise")
                    }
                } label: { Label("More", systemImage: "ellipsis.circle") }
            }
        }
        .confirmationDialog("Start \"\(path.title)\" over?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Start Over", role: .destructive) { store.reset(path) }
        } message: {
            Text("Every step goes back to locked, except the first.")
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
