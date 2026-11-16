# Glassist

Two quiet, frosted-glass Todoist panels for your Mac. 原生 macOS 双面板待办工具。

Glassist is a menu-bar app built with SwiftUI + AppKit. Each independently draggable panel shows an existing personal Todoist filter. This is a desktop companion app, not a WidgetKit extension.

## First version

- Two independent panels, with saved positions and per-panel filter, title, size, font and glass tint controls.
- Real behind-window material, light/dark/system appearance, desktop or floating placement, position lock.
- Existing personal filters read from Todoist; grouped queries, cursor pagination and duplicate-safe counts.
- Per-filter overdue/today counts in the Todoist account timezone. Overdue means a date before today; today's timed tasks stay in today's count.
- Automatic refresh every 1, 2 or 5 minutes while running and awake, plus manual/wake refresh.
- Open tasks in Todoist; complete tasks, including advancing recurring tasks. Failed or ambiguous completion is not automatically retried.
- Local demo mode before connecting. No real account data or reference screenshots are included in this repository.

## Build and open

Requires an Apple Silicon Mac, macOS 13+, and Xcode Command Line Tools with Swift 5.9+ (or Xcode 15+).

```sh
swift test
bash scripts/build-app.sh
open dist/Glassist.app
```

Or open `Package.swift` in Xcode. The build script creates `dist/Glassist.app` and an Apple Silicon ZIP. GitHub Actions runs the tests and uploads the same app as a workflow artifact. This development build is ad-hoc signed, not notarized; distributed downloads may require explicit approval in macOS Privacy & Security. There is no need to disable Gatekeeper.

Use the menu-bar icon to show/hide panels, open settings, refresh, restore panel positions, or quit. Drag the blank area at the top of each panel. Choose sizes in settings. Position recovery handles disconnected displays, but Spaces, Stage Manager and full-screen behavior still need manual validation on the target Mac.

## Connect privately

1. Open Glassist settings → Todoist.
2. Open your Todoist integrations settings from the provided link.
3. Paste your personal API token **only into Glassist's local secure field**.
4. Select an existing filter independently for each panel.

The token is validated, then stored in macOS Keychain. It is never written to source, UserDefaults, logs, shell arguments or a server. Networking uses an ephemeral URLSession directly to `api.todoist.com` and refuses redirects. Disconnect removes the Keychain item. Tasks and filter results stay in memory; offline mode can retain only this session's previous result. Appearance and selected filter IDs are saved locally in UserDefaults.

To edit a filter's actual rules, use “在 Todoist 中编辑过滤器”. Glassist reads changes on the next refresh. It does not rewrite your saved filters. API credentials are never required for automated tests.

## Project map

| Path | Purpose |
| --- | --- |
| `Sources/GlassistCore` | API client, filter grouping, task models and timezone-aware counts |
| `Sources/Glassist` | Desktop panels, settings, synchronization state and Keychain |
| `Tests/GlassistCoreTests` | Mocked API, pagination, rate limit, grouping and date tests |
| `docs/ARCHITECTURE.md` | Research, choices, scope and acceptance checklist |
| `scripts/build-app.sh` | Build and package the native app |

## Current limits

Personal filters only; workspace/team filters, persistent offline cache, OAuth distribution, launch-at-login and a WidgetKit extension are deferred. Grouped filters preserve group order and Todoist's returned task order; advanced Todoist display/sort settings are not mirrored. Unusual filter grammar may need compatibility testing. There is no background sync after quitting or during sleep. System Reduce Transparency can make materials opaque.

The public repository contains generic demo content only. Repository membership is not modified; no ChatGPT collaborator or co-author trailer is added by this project setup.
