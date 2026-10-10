import PianoCore
import SwiftUI

/// The card shown over the practice screen when a song is played to the end: green when it passed
/// (no or only a few mistakes), orange when it needs more practice (the same run that marks the song difficult).
struct PracticeResultView: View {
    let result: PracticeResult
    let onAgain: () -> Void
    let onClose: () -> Void

    private var color: Color { result.grade.passed ? .green : .orange }

    private var icon: String {
        switch result.grade {
        case .perfect: "star.circle.fill"
        case .almost: "checkmark.circle.fill"
        case .needsPractice: "arrow.clockwise.circle.fill"
        }
    }

    private var title: String {
        switch result.grade {
        case .perfect: "Perfect!"
        case .almost: "Well done!"
        case .needsPractice: "Keep practising"
        }
    }

    private var message: String {
        switch result.grade {
        case .perfect: "You played the whole song without a mistake."
        case .almost: "Almost perfect: just \(result.mistakes) \(result.mistakes == 1 ? "mistake" : "mistakes")."
        case .needsPractice:
            result.timed ? "Try it again, maybe at a slower speed or in wait mode first."
                         : "Try it again slowly, a few bars at a time."
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundStyle(color)
                Text(title).font(.largeTitle.bold())
                Text(message)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                HStack(spacing: 24) {
                    if result.timed {
                        stat("Played", "\(result.played) of \(result.total)")
                        stat("Missed", "\(result.missed)")
                    } else {
                        stat("Notes", "\(result.total)")
                    }
                    stat("Wrong", "\(result.wrong)")
                }
                .padding(.vertical, 4)
                HStack(spacing: 16) {
                    Button(action: onAgain) {
                        Label("Practice Again", systemImage: "arrow.counterclockwise").frame(minWidth: 150)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                    Button(action: onClose) { Text("Close").frame(minWidth: 80) }
                        .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding(32)
            .frame(maxWidth: 460)
            .background {
                RoundedRectangle(cornerRadius: 24).fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 24).fill(color.opacity(0.15))
            }
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(color, lineWidth: 3))
            .shadow(radius: 20)
            .padding()
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.monospacedDigit().bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
