import Foundation

/// In-app deep links surfaced from the widget / Live Activity.
///
/// Format: `willpower://habit/<UUID>` — selects the Today tab and focuses
/// the specified habit in the deck.
enum DeepLink: Equatable {
    case habit(UUID)

    static let scheme = "willpower"

    static func from(_ url: URL) -> DeepLink? {
        guard url.scheme == scheme else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        // URL("willpower://habit/<id>") → host = "habit", path = "/<id>"
        switch url.host {
        case "habit":
            guard let raw = parts.first, let id = UUID(uuidString: raw) else { return nil }
            return .habit(id)
        default:
            return nil
        }
    }

    var url: URL {
        switch self {
        case .habit(let id):
            URL(string: "\(Self.scheme)://habit/\(id.uuidString)")!
        }
    }
}
