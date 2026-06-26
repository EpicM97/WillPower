import Foundation

enum EnergyLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case low = 0
    case mid = 1
    case high = 2

    static func < (lhs: EnergyLevel, rhs: EnergyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
