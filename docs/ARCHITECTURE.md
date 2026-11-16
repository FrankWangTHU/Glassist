# Glassist 0.2: system widgets

The user's updated requirement is Notification Center integration, system small/medium/large sizes, and glass that matches neighboring Apple widgets. The independent NSPanel design from 0.1 is retired. There is no automatic desktop overlay or custom always-on-top window.

## UI and lifecycle

A SwiftUI settings app embeds a WidgetKit extension. `AppIntentConfiguration` obtains saved-filter choices from a local catalog using `AppEntity`/`EntityQuery`. Each instance stores its own filter ID. The timeline provider re-reads the chosen filter's latest expression from Todoist, fetches every task page, and renders a snapshot.

The extension declares `.systemSmall`, `.systemMedium`, and `.systemLarge`. It uses `containerBackground(.fill.tertiary, for: .widget)` and semantic foreground styles. macOS renders/removes/tints the container as appropriate. There are no custom NSVisualEffectViews, backdrop tricks, arbitrary blur sliders or custom corner radii. Small widgets show up to 3 rows; medium 3; large 8, with remaining-count text on larger sizes. WidgetKit is a glanceable surface, not a freely scrolling app window.

Normal task titles deep-link to Todoist. Ordinary task completion uses an extension AppIntent and shared Keychain credentials. Recurring completion deliberately opens Todoist; no repeated advancement is possible from the widget itself. Completion claims are written before submitting, and ambiguous writes are never retried automatically. Reconnecting clears completion locks after the user checks results in Todoist.

## Shared storage and privacy

Both targets must be signed by the same team with the same App Group and Keychain Sharing entitlement. Token storage uses `kSecUseDataProtectionKeychain`, a team-prefixed shared access group and device-only accessibility. No credential is passed through a URL or kept in the app-group JSON cache. No credentials are stored in CI.

The macOS app group is `$(DEVELOPMENT_TEAM).com.frankwang.Glassist`; Keychain sharing independently uses `$(AppIdentifierPrefix)com.frankwang.Glassist.shared`. The two prefixes are resolved from actual signing settings/profiles. A git-ignored local xcconfig supplies the team to both targets. This avoids a mismatch where one macOS profile contains a registered `group.*` identifier while the extension only contains the team's wildcard.

A private app-group JSON file contains filter metadata, task snapshots, account generation and completion claims. A process-shared file lock serializes changes. Disconnect removes the shared credential and resets the state. Connecting invalidates the old generation before replacing the credential. A response from an earlier account cannot repopulate the cache after a switch. Confirmed completion is removed even if an older network response arrives later.

Full filter sync is followed by an incremental sync. Task reads follow cursor pagination; grouped expressions are queried independently. Counts deduplicate IDs and use account timezone calendar dates. Deleted filters produce an explicit empty/error state, never silently select another filter. Offline results preserve their original timestamp. Completion buttons disable for very old cached data and locked tasks.

## Refresh constraints

The extension requests another timeline in 15 minutes; macOS decides the actual time. The host can request reloads after connection or manual refresh, but these requests do not bypass the system budget. The extension fetches directly, so it does not require the settings app to remain open. Refresh is not guaranteed during sleep or at minute-level intervals.

## Build and validation boundary

`swift test` exercises core logic. The Xcode scheme builds both the app and extension and embeds the extension under Contents/PlugIns. CI disables signing only for compilation and exports an explicitly UNSIGNED archive. Native gallery registration, signed shared-container access and a real account connection must be validated with a locally provisioned team. Compilation alone is not proof that the system can install or display the widget.

Local verification on 2026-11-17 passed all 13 tests, signed installation, macOS extension registration and shared-container creation on Apple Silicon with Xcode 27.2. The user confirmed Todoist connection and a populated Notification Center widget. Remaining manual acceptance: two independently configured instances, all 3 sizes, system clear/tinted/full-color appearances, task opening, real non-recurring completion using a disposable task, sleep/wake, disconnect across visible widgets, and keychain lock/unlock.

## Primary sources

- [Todoist API](https://developer.todoist.com/api/v1/)
- [Configurable widgets](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget)
- [System widget backgrounds](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background)
- [Widget refresh scheduling](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
- [Widget interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- [App groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [Shared Keychain](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps)
