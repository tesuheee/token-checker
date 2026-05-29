@testable import TokenChecker
import XCTest

final class DomainErrorLocalizationTests: XCTestCase {
    func testDomainErrorsDefaultToJapaneseLocalizedErrorDescriptions() {
        XCTAssertEqual(
            DomainError.timeout.errorDescription,
            "通信がタイムアウトしました。"
        )
    }

    func testDomainErrorsCanRenderInSelectedLanguage() {
        XCTAssertEqual(
            DomainError.anthropicHTTP(status: 500).localizedDescription(language: .english),
            "Anthropic API error (status 500)"
        )
        XCTAssertEqual(
            DomainError.decoding("bad payload").localizedDescription(language: .simplifiedChinese),
            "响应解码失败：bad payload"
        )
    }

    func testCodexDaemonErrorsRenderInSelectedLanguage() {
        XCTAssertEqual(
            DomainError.codexDaemonTimeout.localizedDescription(language: .english),
            "codex app-server daemon start timed out (5s)"
        )
        XCTAssertEqual(
            DomainError.codexDaemonFailed(exitCode: 2).localizedDescription(language: .japanese),
            "codex app-server daemon start に失敗しました (exit=2)"
        )
        XCTAssertEqual(
            DomainError.codexDaemonSpawnFailed("missing binary").localizedDescription(language: .simplifiedChinese),
            "codex app-server daemon start 启动失败：missing binary"
        )
    }
}
