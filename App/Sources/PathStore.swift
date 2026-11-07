import Foundation
import PianoCore

/// Keeps the player's `PathProgress` for every guided path, saved in UserDefaults ("pathProgress", JSON keyed by path id).
final class PathStore: ObservableObject {
    @Published private(set) var progress: [String: PathProgress] = [:]
    private static let defaultsKey = "pathProgress"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey) {
            progress = (try? JSONDecoder().decode([String: PathProgress].self, from: data)) ?? [:]
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
