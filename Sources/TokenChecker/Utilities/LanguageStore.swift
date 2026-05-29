import Foundation
import Observation

@MainActor
@Observable
final class LanguageStore {
    static let languageKey = "appLanguage"

    private let defaults: UserDefaults

    var selectedLanguage: AppLanguage {
        didSet {
            defaults.set(selectedLanguage.rawValue, forKey: Self.languageKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.languageKey),
           let language = AppLanguage(rawValue: raw) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .default
        }
    }
}
