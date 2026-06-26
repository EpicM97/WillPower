import SwiftUI

/// 3-screen first-launch tour. Stored "done" flag in UserDefaults so it
/// doesn't show again. Skippable.
struct OnboardingView: View {
    static let doneKey = "WillPower.onboarding.didShow.v1"

    let onFinish: () -> Void
    @State private var page: Int = 0

    var body: some View {
        VStack {
            TabView(selection: $page) {
                slide(
                    icon: "bolt.heart.fill",
                    title: "Budget time, don't schedule it.",
                    body: "WillPower treats your day as a budget. You decide what's worth your minutes — habits compress to fit reality, never the other way around.",
                    tint: .indigo,
                    tag: 0
                )
                slide(
                    icon: "flame.fill",
                    title: "Match your energy.",
                    body: "Every habit has an energy level — high, mid, or low. The deck surfaces what fits how you actually feel right now.",
                    tint: .orange,
                    tag: 1
                )
                slide(
                    icon: "timer",
                    title: "Live Activities track the work.",
                    body: "Tap play on a habit — the lock screen and Dynamic Island show your timer. Stop = auto-logged. No friction.",
                    tint: .blue,
                    tag: 2
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    UserDefaults.standard.set(true, forKey: Self.doneKey)
                    onFinish()
                }
            } label: {
                Text(page == 2 ? "Get started" : "Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()

            Button("Skip") {
                UserDefaults.standard.set(true, forKey: Self.doneKey)
                onFinish()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom)
        }
    }

    private func slide(icon: String, title: String, body: String, tint: Color, tag: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 84))
                .foregroundStyle(tint)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .tag(tag)
    }
}
