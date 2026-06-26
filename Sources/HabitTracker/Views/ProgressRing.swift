import SwiftUI

/// Things3-inspired ring component. Fills clockwise from 12 o'clock.
struct ProgressRing: View {
    let progress: Double
    var tint: Color = .accentColor
    var lineWidth: CGFloat = 8
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0, min(1.0, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)
        }
        .frame(width: size, height: size)
    }
}

/// Larger labelled variant for the Evening Ritual hero.
struct LabelledProgressRing: View {
    let progress: Double
    let label: String
    var tint: Color = .indigo
    var size: CGFloat = 160

    var body: some View {
        ZStack {
            ProgressRing(progress: progress, tint: tint, lineWidth: 14, size: size)
            VStack(spacing: 2) {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
