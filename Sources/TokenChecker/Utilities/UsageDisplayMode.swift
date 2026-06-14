import SwiftUI

enum UsageDisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case used
    case remaining

    var id: String { rawValue }

    func label(language: AppLanguage) -> String {
        switch self {
        case .used:
            return L10n.tr("display_mode.used", language: language)
        case .remaining:
            return L10n.tr("display_mode.remaining", language: language)
        }
    }

    func value(for limit: RateLimit) -> Double {
        switch self {
        case .used:
            return limit.utilization
        case .remaining:
            return 1.0 - limit.utilization
        }
    }

    func percent(for limit: RateLimit) -> Int {
        Int((clampedValue(for: limit) * 100).rounded())
    }

    func clampedValue(for limit: RateLimit) -> Double {
        min(max(value(for: limit), 0), 1)
    }

    func color(for limit: RateLimit) -> Color {
        switch self {
        case .used:
            let value = limit.utilization
            if value < 0.7 { return .green }
            if value < 0.85 { return .orange }
            return .red
        case .remaining:
            let value = clampedValue(for: limit)
            if value > 0.3 { return .green }
            if value > 0.15 { return .orange }
            return .red
        }
    }

    static let `default`: UsageDisplayMode = .used
}
