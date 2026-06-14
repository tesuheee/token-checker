import Foundation
import OSLog

/// Headroom と同じく、Codex CLI の認証ファイルを使って usage API を直接読む経路。
///
/// `codex app-server` は CLI の配布形態や daemon 仕様変更の影響を受けやすい。
/// 直接API経路は子プロセスを起動せず、期限切れトークンを refresh token で更新してから
/// usage を取得するため、メニューバーアプリの定期取得と相性がよい。
struct CodexDirectUsageAPIClient: Sendable {
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private static let tokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    private static let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"

    private let store: CodexAuthStore

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(
            configuration: config,
            delegate: CodexNoRedirectDelegate.shared,
            delegateQueue: nil
        )
    }()

    init(store: CodexAuthStore = .init()) {
        self.store = store
    }

    func fetch() async throws -> ServiceUsage {
        var credentials = try store.read()
        var credentialRefreshed = false

        if shouldRefresh(credentials) {
            credentials = try await refresh(credentials)
            credentialRefreshed = true
        }

        for attempt in 0..<2 {
            let (data, response) = try await sendUsageRequest(credentials: credentials)
            guard let http = response as? HTTPURLResponse else {
                throw DomainError.invalidResponse
            }

            switch http.statusCode {
            case 200:
                let dto = try decodeUsage(data)
                return dto.toServiceUsage()
            case 401, 403:
                if attempt == 0,
                   let refreshToken = credentials.refreshToken,
                   !refreshToken.isEmpty {
                    credentials = try await refresh(credentials)
                    credentialRefreshed = true
                    continue
                }
                throw DomainError.codexUnauthorized
            case 429:
                throw DomainError.codexRateLimited(retryAfter: retryAfter(from: http))
            default:
                throw DomainError.codexHTTP(status: http.statusCode)
            }
        }

        if credentialRefreshed {
            Logger.codex.debug("Codex credentials were refreshed but usage retry did not complete")
        }
        throw DomainError.invalidResponse
    }

    private func sendUsageRequest(credentials: CodexCredentials) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        if let accountId = credentials.accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        do {
            return try await Self.session.data(for: request)
        } catch {
            throw DomainError.network(error.localizedDescription)
        }
    }

    private func refresh(_ credentials: CodexCredentials) async throws -> CodexCredentials {
        guard let refreshToken = credentials.refreshToken, !refreshToken.isEmpty else {
            throw DomainError.codexUnauthorized
        }

        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.clientId,
        ])

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch {
            throw DomainError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw DomainError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw DomainError.codexUnauthorized
        }

        let token = try JSONDecoder().decode(CodexTokenResponse.self, from: data)
        guard let accessToken = token.accessToken, !accessToken.isEmpty else {
            throw DomainError.codexUnauthorized
        }

        let idToken = token.idToken ?? credentials.idToken
        let accountId = token.accountId
            ?? Self.extractAccountId(from: idToken)
            ?? credentials.accountId
        let expiresAtMs = Date().timeIntervalSince1970Milliseconds
            + Int64((token.expiresIn ?? 8 * 60 * 60) * 1000)

        let refreshed = CodexCredentials(
            accessToken: accessToken,
            refreshToken: token.refreshToken ?? credentials.refreshToken,
            idToken: idToken,
            accountId: accountId,
            expiresAtMs: expiresAtMs
        )
        try store.write(refreshed)
        return refreshed
    }

    private func decodeUsage(_ data: Data) throws -> CodexDirectUsageDTO {
        do {
            return try JSONDecoder().decode(CodexDirectUsageDTO.self, from: data)
        } catch {
            throw DomainError.decoding("Codex usage API: \(error.localizedDescription)")
        }
    }

    private func shouldRefresh(_ credentials: CodexCredentials) -> Bool {
        guard credentials.expiresAtMs > 0 else { return false }
        let now = Date().timeIntervalSince1970Milliseconds
        return now >= credentials.expiresAtMs - 30_000
    }

    private func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        let raw = response.value(forHTTPHeaderField: "Retry-After")
            ?? response.value(forHTTPHeaderField: "retry-after")
        return raw.flatMap(TimeInterval.init)
    }

    private func formEncoded(_ pairs: [String: String]) -> Data {
        pairs
            .map { key, value in
                "\(escape(key))=\(escape(value))"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private func escape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    static func extractAccountId(from idToken: String?) -> String? {
        guard let idToken, !idToken.isEmpty else { return nil }
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: payload),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let accountId = root["chatgpt_account_id"] as? String, !accountId.isEmpty {
            return accountId
        }
        if let auth = root["https://api.openai.com/auth"] as? [String: Any],
           let accountId = auth["chatgpt_account_id"] as? String,
           !accountId.isEmpty {
            return accountId
        }
        return nil
    }
}

private struct CodexTokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let idToken: String?
    let accountId: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case accountId = "account_id"
        case expiresIn = "expires_in"
    }
}

struct CodexDirectUsageDTO: Decodable, Sendable {
    let rateLimit: RateLimitBody?
    let primaryWindow: Window?
    let secondaryWindow: Window?

    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }

    struct RateLimitBody: Decodable, Sendable {
        let primaryWindow: Window?
        let secondaryWindow: Window?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    struct Window: Decodable, Sendable {
        let usedPercent: Double?
        let resetAt: Int64?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
        }
    }

    func toServiceUsage() -> ServiceUsage {
        let primary = rateLimit?.primaryWindow ?? primaryWindow
        let secondary = rateLimit?.secondaryWindow ?? secondaryWindow
        return ServiceUsage(
            fiveHour: primary.flatMap(Self.toRateLimit),
            weekly: secondary.flatMap(Self.toRateLimit),
            weeklySonnet: nil
        )
    }

    private static func toRateLimit(_ window: Window) -> RateLimit? {
        guard let used = window.usedPercent,
              let reset = window.resetAt,
              reset > 0 else {
            return nil
        }
        return RateLimit(
            utilization: max(0, used / 100.0),
            resetsAt: Date(timeIntervalSince1970: TimeInterval(reset))
        )
    }
}

private final class CodexNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = CodexNoRedirectDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private extension Date {
    var timeIntervalSince1970Milliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }
}
