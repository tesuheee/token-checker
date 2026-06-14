import Foundation

enum L10n {
    static func tr(_ key: String, language: AppLanguage) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle(for: language), value: key, comment: "")
    }

    static func format(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: tr(key, language: language), locale: language.locale, arguments: arguments)
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        guard let path = resourceBundle.path(forResource: language.resourceName, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return resourceBundle
        }
        return bundle
    }

    private static let resourceBundle: Bundle = {
        let bundleName = "TokenChecker_TokenChecker.bundle"
        let candidates = [
            // .app 配布時の正規位置。
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            // SwiftPM 生成アクセサの探索位置。開発時の互換用。
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
        ]

        for url in candidates {
            if let url, let bundle = Bundle(url: url) {
                return bundle
            }
        }

        // `swift test` や `swift run` では SwiftPM の生成アクセサを使う。
        return .module
    }()
}
