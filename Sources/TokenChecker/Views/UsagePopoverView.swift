import SwiftUI
import AppKit

struct UsagePopoverView: View {
    @Bindable var viewModel: UsageViewModel
    @Bindable var languageStore: LanguageStore
    @ObservedObject var launchAtLogin: LaunchAtLoginStore

    private var language: AppLanguage { languageStore.selectedLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ServiceSectionView(
                title: "Claude Code",
                brand: .claude,
                result: viewModel.snapshot.claude,
                language: language,
                displayMode: viewModel.displayMode,
                loginAction: { viewModel.openClaudeLogin() }
            )

            Divider()

            ServiceSectionView(
                title: "Codex",
                brand: .codex,
                result: viewModel.snapshot.codex,
                language: language,
                displayMode: viewModel.displayMode,
                loginAction: { viewModel.openCodexLogin() }
            )

            Divider()
            settingsBlock
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Text("Token Checker")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
    }

    private var settingsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.tr("settings.refresh_interval", language: language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $viewModel.pollingInterval) {
                    ForEach(PollingInterval.allCases) { interval in
                        Text(interval.label(language: language)).tag(interval)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            HStack {
                Text(L10n.tr("settings.display_mode", language: language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $viewModel.displayMode) {
                    ForEach(UsageDisplayMode.allCases) { mode in
                        Text(mode.label(language: language)).tag(mode)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            HStack {
                Text(L10n.tr("settings.language", language: language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $languageStore.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(L10n.tr(option.displayKey, language: option)).tag(option)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            HStack {
                Text(L10n.tr("settings.launch_at_login", language: language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { _ in launchAtLogin.toggle() }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
        }
    }

    private var footer: some View {
        HStack {
            if viewModel.snapshot.fetchedAt > .distantPast {
                Text(L10n.format(
                    "footer.updated_at",
                    language: language,
                    formattedTime(viewModel.snapshot.fetchedAt)
                ))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help(L10n.tr("footer.refresh_now", language: language))

            Button(L10n.tr("footer.quit", language: language)) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
