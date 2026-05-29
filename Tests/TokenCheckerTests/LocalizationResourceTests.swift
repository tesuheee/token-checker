import Foundation
import XCTest

final class LocalizationResourceTests: XCTestCase {
    private let languageCodes = ["ja", "en", "zh-Hans"]

    func testAllLocalizationsHaveSameKeys() throws {
        let keySets = try Dictionary(uniqueKeysWithValues: languageCodes.map { code in
            (code, try localizationKeys(for: code))
        })

        let japaneseKeys = try XCTUnwrap(keySets["ja"])
        XCTAssertFalse(japaneseKeys.isEmpty, "Japanese localization must not be empty")

        for code in languageCodes where code != "ja" {
            XCTAssertEqual(keySets[code], japaneseKeys, "\(code) localization keys must match Japanese")
        }
    }

    func testInfoPlistDeclaresJapaneseBaseAndSupportedLocalizations() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let plistURL = root.appending(path: "Resources/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        XCTAssertEqual(plist["CFBundleDevelopmentRegion"] as? String, "ja")
        XCTAssertEqual(plist["CFBundleLocalizations"] as? [String], languageCodes)
    }

    private func localizationKeys(for code: String) throws -> Set<String> {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let url = root
            .appending(path: "Sources/TokenChecker/Resources")
            .appending(path: "\(code).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        return Set(plist.keys)
    }
}
