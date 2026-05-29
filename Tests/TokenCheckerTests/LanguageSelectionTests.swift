import Foundation
@testable import TokenChecker
import XCTest

@MainActor
final class LanguageSelectionTests: XCTestCase {
    func testLanguageStoreDefaultsToJapaneseWhenNoPreferenceExists() {
        let defaults = makeDefaults()

        let store = LanguageStore(defaults: defaults)

        XCTAssertEqual(store.selectedLanguage, .japanese)
    }

    func testLanguageStorePersistsSelectedLanguage() {
        let defaults = makeDefaults()
        let store = LanguageStore(defaults: defaults)

        store.selectedLanguage = .simplifiedChinese

        XCTAssertEqual(defaults.string(forKey: LanguageStore.languageKey), "zh-Hans")
        XCTAssertEqual(LanguageStore(defaults: defaults).selectedLanguage, .simplifiedChinese)
    }

    func testLocalizationLookupUsesSelectedLanguageBundle() {
        XCTAssertEqual(L10n.tr("settings.refresh_interval", language: .japanese), "更新間隔")
        XCTAssertEqual(L10n.tr("settings.refresh_interval", language: .english), "Refresh interval")
        XCTAssertEqual(L10n.tr("settings.refresh_interval", language: .simplifiedChinese), "刷新间隔")
    }

    func testLocalizationFormattingUsesSelectedLanguageBundle() {
        XCTAssertEqual(L10n.format("footer.updated_at", language: .english, "10:00"), "Updated: 10:00")
        XCTAssertEqual(L10n.format("footer.updated_at", language: .simplifiedChinese, "10:00"), "更新：10:00")
    }

    func testPollingIntervalLabelsUseSelectedLanguage() {
        XCTAssertEqual(PollingInterval.sec30.label(language: .japanese), "30秒")
        XCTAssertEqual(PollingInterval.min5.label(language: .english), "5 min")
        XCTAssertEqual(PollingInterval.min10.label(language: .simplifiedChinese), "10 分钟")
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "TokenCheckerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
