#if canImport(UIKit)
import UIKit

enum Haptics {
    /// Light tap — used for routine confirms (toggle compress, dismiss).
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Success — used when a session is completed.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warning — used when a running session crosses its budget.
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
#else
enum Haptics {
    static func tap() {}
    static func success() {}
    static func warning() {}
}
#endif
