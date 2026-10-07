import PianoCore
import SwiftUI

/// Piano keyboard strip. Pressed keys are green (correct) or red (wrong); after a wrong note the
/// keys still needed are orange.
/// Tapping keys sends events, so the app can be tried without a real keyboard.
struct KeyboardView: View {
    var range: ClosedRange<UInt8> = 48...84           // C3...C6
    var states: [UInt8: WaitModeEngine.KeyState] = [:]
    /// Keys currently held (by the piano or on screen); used so a held key doesn't re-send note-on.
    var pressed: Set<UInt8> = []
    /// Show the note name (e.g. "C4", "F#4") on every key.
    var showLabels = true
    var onPress: (UInt8) -> Void = { _ in }
    var onRelease: (UInt8) -> Void = { _ in }

    private var whiteKeys: [UInt8] { range.filter { !NoteName.isBlackKey($0) } }

    var body: some View {
        GeometryReader { geo in
            let whiteWidth = geo.size.width / CGFloat(whiteKeys.count)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whiteKeys, id: \.self) { pitch in
                        key(pitch, black: false)
                            .frame(width: whiteWidth, height: geo.size.height)
                    }
                }
                ForEach(range.filter { NoteName.isBlackKey($0) }, id: \.self) { pitch in
                    let whitesBefore = whiteKeys.filter { $0 < pitch }.count
                    key(pitch, black: true)
                        .frame(width: whiteWidth * 0.6, height: geo.size.height * 0.62)
                        .offset(x: whiteWidth * CGFloat(whitesBefore) - whiteWidth * 0.3)
                }
            }
        }
    }

    private func key(_ pitch: UInt8, black: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color(for: pitch, black: black))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.5), lineWidth: 1))
            .overlay(alignment: .bottom) {
                if showLabels {
                    Text(NoteName.of(pitch))
                        .font(.caption2)
                        .foregroundColor(black ? .white : .black.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 1)
                        .padding(.bottom, 4)
                        .allowsHitTesting(false)
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed.contains(pitch) { onPress(pitch) } }
                .onEnded { _ in onRelease(pitch) })
    }

    private func color(for pitch: UInt8, black: Bool) -> Color {
        switch states[pitch] {
        case .correct: return .green
        case .wrong: return .red
        case .missed: return .orange
        case nil: return black ? .black : .white
        }
    }
}
