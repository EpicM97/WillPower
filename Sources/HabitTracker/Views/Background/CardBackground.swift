import SwiftUI

/// The user's chosen backing for the "Today's budget" hero card. Persisted as
/// JSON; rendered by `budgetCardBackground`. Sourced from three places (QA 2c):
/// a solid color board + stock images (both Supabase-hosted, see increment 2)
/// and the user's own uploads (local).
enum CardBackground: Codable, Equatable {
    /// Default neutral system surface (no customization).
    case surface
    /// A solid color from the board, stored as a "#RRGGBB" hex string.
    case solid(hex: String)
    /// A stock image — Supabase Storage object path under the `backgrounds` bucket.
    case remote(path: String)
    /// A user upload, stored on-device under this filename (see `LocalImageStore`).
    case local(filename: String)

    /// True when the background is image-backed and needs a legibility scrim +
    /// light foreground text over it.
    var isImage: Bool {
        switch self {
        case .remote, .local: return true
        case .surface, .solid: return false
        }
    }

    /// Curated fallback color board shipped in-app until the Supabase-hosted
    /// `colors.json` board lands (increment 2). Calm / deep / muted tones.
    static let defaultColorBoard: [String] = [
        "#2D3142", "#4F5D75", "#1B998B", "#3D5A80",
        "#5E548E", "#9A8C98", "#386641", "#BC4749"
    ]

    /// Public URL for a stock object in the Supabase `backgrounds` bucket.
    static func publicStorageURL(path: String, bucket: String = "backgrounds") -> URL? {
        guard let config = try? SupabaseConfig.fromBundle() else { return nil }
        return config.url.appendingPathComponent("storage/v1/object/public/\(bucket)/\(path)")
    }
}

extension Color {
    /// Parses "#RRGGBB" or "RRGGBB". Returns nil for anything else.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }

    /// sRGB components, for tests/inspection.
    var rgbComponents: (r: Double, g: Double, b: Double) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
        #else
        return (0, 0, 0)
        #endif
    }
}
