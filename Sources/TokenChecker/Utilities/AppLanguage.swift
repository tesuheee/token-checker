import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case japanese = "ja"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var resourceName: String { rawValue }

    var displayKey: String {
        switch self {
        case .japanese: return "language.japanese"
        case .english: return "language.english"
        case .simplifiedChinese: return "language.simplified_chinese"
        }
    }

    var locale: Locale {
        switch self {
        case .japanese: return Locale(identifier: "ja_JP")
        case .english: return Locale(identifier: "en")
        case .simplifiedChinese: return Locale(identifier: "zh_Hans")
        }
    }

    static let `default`: AppLanguage = .japanese
}
