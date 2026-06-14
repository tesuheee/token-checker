import Foundation

struct CodexCredentials: Equatable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var idToken: String?
    var accountId: String?
    var expiresAtMs: Int64
}

/// `~/.codex/auth.json` の OAuth トークンを読み書きする。
///
/// Codex CLI と同じ認証ファイルを使うため、ユーザーはこれまで通り
/// `codex login` でログインできる。書き戻し時は未知のトップレベルキーを
/// 可能な範囲で保持し、トークン更新部分だけを差し替える。
struct CodexAuthStore: Sendable {
    let authURL: URL

    init(authURL: URL = Self.defaultAuthURL()) {
        self.authURL = authURL
    }

    func read() throws -> CodexCredentials {
        let root = try readRoot()
        guard let tokens = root["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty else {
            throw DomainError.codexAuthMissing
        }

        return CodexCredentials(
            accessToken: accessToken,
            refreshToken: tokens["refresh_token"] as? String,
            idToken: tokens["id_token"] as? String,
            accountId: tokens["account_id"] as? String,
            expiresAtMs: Self.int64(from: tokens["expires_at_ms"]) ?? 0
        )
    }

    func write(_ credentials: CodexCredentials) throws {
        var root = (try? readRoot()) ?? [:]
        var tokens = (root["tokens"] as? [String: Any]) ?? [:]

        root["auth_mode"] = "chatgpt"
        tokens["access_token"] = credentials.accessToken
        if let refreshToken = credentials.refreshToken, !refreshToken.isEmpty {
            tokens["refresh_token"] = refreshToken
        }
        if let idToken = credentials.idToken, !idToken.isEmpty {
            tokens["id_token"] = idToken
        }
        if let accountId = credentials.accountId, !accountId.isEmpty {
            tokens["account_id"] = accountId
        }
        if credentials.expiresAtMs > 0 {
            tokens["expires_at_ms"] = credentials.expiresAtMs
        }

        root["tokens"] = tokens
        root["last_refresh"] = ISO8601DateFormatter.withFractional.string(from: Date())

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(
            at: authURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: authURL, options: [.atomic])
    }

    private func readRoot() throws -> [String: Any] {
        let data = try Self.readDataWithRetry(from: authURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DomainError.codexAuthMissing
        }
        return root
    }

    private static func readDataWithRetry(from url: URL) throws -> Data {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                return try Data(contentsOf: url)
            } catch CocoaError.fileReadNoSuchFile,
                    CocoaError.fileNoSuchFile,
                    CocoaError.fileReadNoPermission {
                throw DomainError.codexAuthMissing
            } catch {
                lastError = error
                if attempt < 2 {
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
        }
        throw DomainError.network(lastError?.localizedDescription ?? "failed to read Codex auth file")
    }

    private static func int64(from value: Any?) -> Int64? {
        switch value {
        case let int as Int:
            return Int64(int)
        case let int64 as Int64:
            return int64
        case let double as Double:
            return Int64(double)
        case let string as String:
            return Int64(string)
        default:
            return nil
        }
    }

    private static func defaultAuthURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex")
            .appendingPathComponent("auth.json")
    }
}
