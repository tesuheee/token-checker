import Foundation

/// Codex の rate limit を取得する。
///
/// まず Headroom と同じ直接API経路を使う。これは `~/.codex/auth.json` の OAuth
/// トークンを読み、期限切れ時は refresh token で更新してから usage API を叩く。
/// 直接API経路が失敗した場合のみ、既存の `codex app-server` 経路にフォールバックする。
final class CodexUsageProvider: UsageProvider, @unchecked Sendable {
    private let client: CodexAppServerClient
    private let directClient: CodexDirectUsageAPIClient

    init(
        client: CodexAppServerClient = .init(),
        directClient: CodexDirectUsageAPIClient = .init()
    ) {
        self.client = client
        self.directClient = directClient
    }

    func fetch() async throws -> ServiceUsage {
        do {
            return try await directClient.fetch()
        } catch let directError {
            do {
                return try await fetchViaAppServer()
            } catch let appServerError {
                throw preferredError(directError: directError, appServerError: appServerError)
            }
        }
    }

    private func fetchViaAppServer() async throws -> ServiceUsage {
        do {
            try await client.start()
            let dto = try await client.readRateLimits()
            return ServiceUsage(
                fiveHour: dto.fiveHourRateLimit(),
                weekly: dto.weeklyRateLimit(),
                weeklySonnet: nil
            )
        } catch DomainError.codexProcessExited {
            // 一度落ちていたら再起動して再試行
            await client.stop()
            try await client.start()
            let dto = try await client.readRateLimits()
            return ServiceUsage(
                fiveHour: dto.fiveHourRateLimit(),
                weekly: dto.weeklyRateLimit(),
                weeklySonnet: nil
            )
        }
    }

    private func preferredError(directError: Error, appServerError: Error) -> Error {
        guard let direct = directError as? DomainError else {
            return appServerError
        }
        return direct
    }

    func shutdown() async {
        await client.stop()
    }
}
