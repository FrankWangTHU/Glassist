# Glassist

Native macOS Todoist widgets for Notification Center and the desktop. 系统原生 Todoist 过滤器小组件。

Version 0.2 replaces the independent desktop panels with a **WidgetKit extension**. Click the date at the top right of macOS to show it alongside Calendar and Weather. Add multiple instances in small, medium or large sizes, each with its own saved personal Todoist filter.

## What changed

- No floating desktop windows are created. The host is a normal settings app with Close and Quit controls.
- Native small/medium/large widget families; macOS owns placement, glass/translucency, rounding, tint and removal.
- Right-click → Edit Glassist to select an existing filter for each instance.
- System-scheduled background refresh; widgets can fetch data after the settings app quits. A 15-minute timeline request is a request, not a guaranteed interval.
- Filter-scoped overdue/today counts, complete paginated reads, grouped query handling and offline timestamps.
- Click a task to open Todoist. Ordinary tasks have AppIntent completion buttons. Recurring tasks open Todoist; direct recurring completion is deferred to avoid double advancement on repeated widget actions.
- Token in a shared **data-protection Keychain** access group. Cached tasks/filters in the signed app group's private container; never in the repository.

## Build / install status

The repository contains an Xcode host app and embedded WidgetKit extension. CI builds both without signing and runs API/storage tests. An unsigned CI artifact **is not a ready-to-install system widget**. No developer certificate, account password or private key belongs in this repository or in chat.

See [local signing and installation](docs/INSTALL.md) before trying to add Glassist to the system gallery. `swift test` runs the tests; `bash scripts/build-app.sh` builds the unsigned Xcode archive on a Mac with Xcode installed. Open **Glassist.xcodeproj**, not Package.swift, to run the full app plus extension.

For a signed local installation, set your team in the ignored `Configuration/LocalSigning.xcconfig` (copy the example), then run `bash scripts/install-local.sh`. Both targets inherit the same settings. Local Apple Silicon verification passed 13 tests, code-signature validation, installation, extension registration and shared-container creation with a free Personal Team. Development profiles are time-limited; see the installation guide for rebuilding.

## Project

| Path | Purpose |
| --- | --- |
| `Sources/Glassist` | Normal settings window and local account connection |
| `Sources/GlassistWidgets` | Widget configuration, timeline, sizes and completion AppIntent |
| `Sources/GlassistCore` | Todoist API, shared cache and credential access |
| `Configuration` | Host/extension Info.plist and entitlements |
| `Glassist.xcodeproj` | Shared scheme with embedded extension |
| `Tests/GlassistCoreTests` | API, dates, account isolation, cache and concurrency |
| `docs/ARCHITECTURE.md` | Design decisions and runtime limits |
