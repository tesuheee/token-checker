import SwiftUI
import AppKit

@main
struct TokenCheckerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = UsageViewModel()
    @State private var languageStore = LanguageStore()
    @StateObject private var launchAtLogin = LaunchAtLoginStore()

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(
                viewModel: viewModel,
                languageStore: languageStore,
                launchAtLogin: launchAtLogin
            )
                .onAppear {
                    launchAtLogin.refresh()
                    // 終了時に codex 子プロセスを始末するためのフックを AppDelegate に登録する。
                    // viewModel 全体ではなく providers だけを閉じ込めた @Sendable クロージャを渡す。
                    appDelegate.shutdownHandler = viewModel.makeShutdownHandler()
                }
        } label: {
            MenuBarLabel(viewModel: viewModel)
                .task(id: viewModel.pollingInterval) {
                    await viewModel.runPollingLoop()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

/// アプリ終了時に子プロセス (`codex app-server`) を確実に terminate するためのデリゲート。
/// 「終了」ボタンも `NSApplication.shared.terminate(nil)` 経由でここを通る。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var shutdownHandler: (@Sendable () async -> Void)?

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        // applicationWillTerminate は AppKit がメインスレッドから呼ぶ前提のため
        // MainActor.assumeIsolated で MainActor isolated な shutdownHandler を取り出す。
        // semaphore.wait でメインスレッドをブロックするため、Task.detached で別スレッドに逃がす。
        // handler 本体は providers だけをキャプチャした @Sendable クロージャで、
        // CodexAppServerClient (actor) のメソッドを await するだけ — MainActor ホップ不要なのでデッドロックしない。
        let handler = MainActor.assumeIsolated { shutdownHandler }
        guard let handler else { return }
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            await handler()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2.0)
    }
}
