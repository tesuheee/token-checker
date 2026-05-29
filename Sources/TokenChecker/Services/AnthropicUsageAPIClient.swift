import Foundation

/// Anthropic の OAuth ベース usage エンドポイントを叩いて生 DTO を返す。
struct AnthropicUsageAPIClient: Sendable {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    /// Bearer トークンを保持したまま追従先へ再送されるのを防ぐため、
    /// 専用 URLSession にリダイレクト不許可のデリゲートを噛ませる。
    /// `URLSession.shared` の既定動作は Authorization ヘッダ込みでリダイレクトを追従するため、
    /// `api.anthropic.com` が MITM / DNS 汚染で Location を返した場合に OAuth トークンが漏れる。
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(
            configuration: config,
            delegate: NoRedirectDelegate.shared,
            delegateQueue: nil
        )
    }()

    func fetch(accessToken: String) async throws -> AnthropicUsageDTO {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch {
            throw DomainError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw DomainError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            break
        case 401:
            throw DomainError.anthropicUnauthorized
        case 429:
            // Retry-After ヘッダがあれば秒数を取り出してユーザに伝える
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")
                              ?? http.value(forHTTPHeaderField: "retry-after"))
                .flatMap(TimeInterval.init)
            throw DomainError.anthropicRateLimited(retryAfter: retryAfter)
        default:
            throw DomainError.anthropicHTTP(status: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(AnthropicUsageDTO.self, from: data)
        } catch {
            throw DomainError.decoding("Anthropic usage: \(error.localizedDescription)")
        }
    }
}

// MARK: - URLSession delegate

/// HTTP リダイレクトを一切許可しないデリゲート。
/// 既定動作だと URLSession は Authorization ヘッダ付きでリダイレクトを追従するため、
/// Bearer トークンが攻撃者ホストに漏れる経路を塞ぐ。`willPerformHTTPRedirection` で
/// `completionHandler(nil)` を返すと URLSession は redirect を打ち切り、呼び出し側へ
/// `URLError.cancelled` を投げる（このアプリではネットワークエラーとして扱う）。
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = NoRedirectDelegate()

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

// MARK: - DTO

struct AnthropicUsageDTO: Decodable, Sendable {
    let fiveHour: BucketDTO?
    let sevenDay: BucketDTO?
    let sevenDaySonnet: BucketDTO?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
    }

    struct BucketDTO: Decodable, Sendable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }
}

extension AnthropicUsageDTO.BucketDTO {
    func toRateLimit() -> RateLimit? {
        guard let utilization, let resetsAt else { return nil }
        guard let date = ISO8601DateFormatter.standard.date(from: resetsAt)
                       ?? ISO8601DateFormatter.withFractional.date(from: resetsAt) else {
            return nil
        }
        return RateLimit(utilization: utilization / 100.0, resetsAt: date)
    }
}

extension ISO8601DateFormatter {
    // ISO8601DateFormatter は Apple ドキュメント上 thread-safe だが Sendable に
    // 非適合のため、Swift 6 strict-concurrency では static let がエラーになる。
    // 初期化後は不変で並列読みのみ行うので nonisolated(unsafe) として扱う。
    nonisolated(unsafe) static let standard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    nonisolated(unsafe) static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
