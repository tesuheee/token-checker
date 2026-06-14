[English](./README.md) [日本語](./README.ja.md)

# Token Checker Fixed Fork

A macOS menu bar app that displays Claude Code and Codex usage in real time.

This repository is a personal fork of [otoha1119/token-checker](https://github.com/otoha1119/token-checker). It keeps the original design and implementation as the base, with additional fixes for npm/nvm Codex CLI installs, menu bar readability, and weekly-window display.

## Changes in This Fork

- Prefer the stdio `codex app-server` flow and prepend the resolved Codex executable directory to the child process `PATH`, which helps npm/nvm installs whose `codex` command runs through `env node`.
- Show the actual Codex RPC error message instead of collapsing RPC errors into `missing result`.
- Match the rendered menu bar label to the active macOS appearance so percentage text remains readable in dark menu bars.
- Show bars for weekly windows. The 5-hour window remains visually primary, while weekly windows use thinner bars.
- Add a display mode setting for used quota (0% to 100%) vs remaining quota (100% to 0%).

<p align="center">
  <img src=".github/assets/fork-menubar-remaining.png" alt="Menu bar showing remaining quota" width="116"/>
  <br/>
  <img src=".github/assets/fork-popover-remaining.png" alt="Popover showing remaining quota" width="327"/>
</p>

## Overview

For accounts already authenticated via `claude login` / `codex login`, this app retrieves rate-limit information through the Anthropic OAuth endpoint and the `codex app-server` JSON-RPC. Results are shown as two donut charts with numeric values in the menu bar; clicking opens a popover with detailed 5-hour and weekly window data.

## Requirements

| Item | Value |
| --- | --- |
| macOS | 14 Sonoma or later |
| Swift | 5.9 or later (Xcode Command Line Tools is sufficient) |
| Claude Code CLI | authenticated via `claude login` |
| Codex CLI | authenticated via `codex login` |

If only one of Claude Code or Codex is available, the other still works.

## Installation

Clone this repository and build on your own machine.

```bash
./Scripts/build.sh --install
```

If no Apple Development signing identity is found, ad-hoc signing is used automatically. A `.app` you built yourself can be launched directly.

After installation, open `TokenChecker` from Finder's Applications folder, or run:

```bash
open /Applications/TokenChecker.app
```

## Usage

First, log in to both services from the terminal:

```bash
claude login
codex login
```

Each uses a browser-based OAuth flow that saves a token to Keychain or `~/.codex/auth.json`. The app reads the saved tokens, so you only need to log in once via the CLI.

The popover shows 5-hour and weekly window usage or remaining quota, reset countdowns, a refresh-interval picker, a display mode picker, and a launch-at-login toggle.

## Data Sources

- **Claude**: retrieves the OAuth access token from Keychain (`Claude Code-credentials`) via `/usr/bin/security`, then issues a GET request to `https://api.anthropic.com/api/oauth/usage` with the `anthropic-beta: oauth-2025-04-20` header.
- **Codex**: spawns the `codex` binary as a subprocess and calls `account/rateLimits/read` via line-delimited JSON-RPC. The binary is discovered by probing common install locations and falling back to `command -v codex` via the user's login shell. A manual override is available via the `UserDefaults` `codexPath` key: `defaults write com.token-checker.app codexPath /abs/path/codex`.

The app tries `codex app-server` first, then falls back to `codex app-server daemon start` plus `codex app-server proxy` when needed. For npm/nvm installs whose `codex` shim requires `node`, the resolved Codex executable directory is prepended to the child process `PATH`.

## Updating

Pull the latest source and rebuild.

```bash
git pull
./Scripts/build.sh --install
```

The existing app is overwritten in place. Settings such as polling interval, display mode, and launch-at-login persist via UserDefaults. If the app is already running, quit it from the menu bar item first, then relaunch.

## Related Project

For Windows, see [Headroom](https://github.com/tesuheee/headroom-ai-usage-monitor), a desktop AI usage monitor for Claude Code and Codex quotas, reset times, OAuth login status, and rate limits.

## Uninstall

```bash
killall TokenChecker
defaults delete com.token-checker.app 2>/dev/null
```

## License

Distributed under the [MIT License](./LICENSE).

"Anthropic", "Claude", and "Codex" are trademarks of their respective owners. This software is not an official product of Anthropic or OpenAI, and is not endorsed or approved by either company.

## Disclaimer

This software is provided "as is", without warranty of any kind regarding operation, safety, or accuracy. Use it at your own risk.

## Acknowledgments

This fork is based on [otoha1119/token-checker](https://github.com/otoha1119/token-checker). Thanks to the original author and contributors.

The UI design references [s-age/ccmeter](https://github.com/s-age/ccmeter) (MIT License). The full MIT license text is included in [`LICENSE`](./LICENSE).
