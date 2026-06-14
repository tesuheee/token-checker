import SwiftUI

/// Claude / Codex 1 サービスぶんの詳細セクション。
/// どのブランドのセクションかを表す。
enum ServiceBrand {
    case claude
    case codex
}

struct ServiceSectionView: View {
    let title: String
    let brand: ServiceBrand
    let result: Result<ServiceUsage, DomainError>?
    let language: AppLanguage
    let displayMode: UsageDisplayMode
    let loginAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                brandMark
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    loginAction()
                } label: {
                    Image(systemName: "person.badge.key")
                }
                .buttonStyle(.borderless)
                .help(L10n.format("service.login.help", language: language, title))
            }

            switch result {
            case .none:
                Text(L10n.tr("status.loading", language: language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            case .some(.success(let usage)):
                usageBlock(usage)
            case .some(.failure(let err)):
                errorBlock(err)
            }
        }
    }

    @ViewBuilder
    private func usageBlock(_ usage: ServiceUsage) -> some View {
        if let five = usage.fiveHour {
            limitRow(label: L10n.tr("window.five_hour", language: language), limit: five)
        } else {
            Text(L10n.tr("window.five_hour.no_data", language: language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }

        if let weekly = usage.weekly {
            limitRow(label: L10n.tr("window.weekly", language: language), limit: weekly)
        }
        if let sonnet = usage.weeklySonnet {
            limitRow(label: L10n.tr("window.weekly_sonnet", language: language), limit: sonnet)
        }
    }

    private func limitRow(label: String, limit: RateLimit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(displayMode.percent(for: limit))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(displayMode.color(for: limit))
            }
            ProgressBarView(
                value: displayMode.clampedValue(for: limit),
                tint: displayMode.color(for: limit)
            )
            Text(resetLabel(limit.resetsAt))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func errorBlock(_ err: DomainError) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(L10n.tr("error.fetch_failed", language: language))
                    .font(.system(size: 12, weight: .medium))
            }
            Text(err.localizedDescription(language: language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var brandMark: some View {
        switch brand {
        case .claude:
            Image(systemName: "sparkles")
        case .codex:
            Image(systemName: "terminal.fill")
        }
    }

    private func resetLabel(_ date: Date) -> String {
        let now = Date()
        if date <= now { return L10n.tr("reset.soon", language: language) }
        let f = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = language.locale
        f.calendar = calendar
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        let rel = f.string(from: now, to: date) ?? "—"
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let absolute = formatter.string(from: date)
        return L10n.format("reset.remaining", language: language, rel, absolute)
    }
}
