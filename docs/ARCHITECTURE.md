# Glassist architecture and implementation plan

Research checked: 2026-11-16. User-selected layout: two independently draggable panels, positioned left/right by default. Repository: FrankWangTHU/Glassist. No repository collaborator changes or ChatGPT co-author attribution.

## Decision

Use SwiftUI for content and settings, AppKit NSPanel for desktop placement, NSVisualEffectView with behind-window blending for frosted material, and Keychain for the local credential. macOS 13+; arm64 build. No Electron, server, subscription infrastructure or third-party widget host.

| Option | Benefit | Relevant limit | Decision |
| --- | --- | --- | --- |
| WidgetKit | System widget gallery, native configuration and AppIntent completion buttons | System-managed background/rendering and refresh budgets; not a continuously running custom window | Possible later companion extension |
| Übersicht | Fast React/CSS iteration and desktop hosting | Additional host dependency; its documented click interaction requires a shortcut/accessibility access; actual desktop blur depends on host behavior | Useful for a disposable prototype, not chosen |
| Native app | Two independent windows, scrolling, menus, direct task completion and real behind-window material | Need packaging/signing and target-Mac checks for Spaces/Stage Manager | Selected |

Do not equate SwiftUI with WidgetKit: this implementation is a native menu-bar app with desktop windows and will not appear in “Edit Widgets”. Material appearance is system-managed and affected by Reduce Transparency; the tint setting adjusts overlay density, not a private blur radius.

## Verified Todoist contract

The current unified API base is `https://api.todoist.com/api/v1/`.

1. `POST /sync`, form body `sync_token=*`, `resource_types=["filters","user"]`: existing personal filters include ID, name and query. Maintain the returned sync token, merge updates and delete tombstones. Follow an initial full sync with an incremental sync because a full sync can be cached.
2. `GET /tasks/filter?query=…&lang=…&limit=200`: query by saved expression, not saved filter ID. Follow `next_cursor` to exhaustion. Language and timezone come from the account context.
3. The filter endpoint does not accept comma-separated multi-filter queries. Split top-level unescaped commas, preserve groups, query each separately and count unique IDs. Do not implement Todoist's full query language locally. Quotes and parentheses are preserved, and errors are visible rather than silently replacing the query.
4. `POST /tasks/{id}/close`: normal tasks and their subtasks are completed; recurring tasks advance to the next occurrence. Submit once and refresh both panels. Do not automatically retry ambiguous writes.
5. `todoist://task?id=…` opens the desktop task; fallback is the Todoist web task route.

These contracts were checked against official documentation. Real-account verification still requires the user to connect locally; mock tests are not evidence of authenticated API success.

## Data and state

- Two panel settings records in UserDefaults; credentials in Keychain only.
- URLSession ephemeral transport, redirects refused; no raw error bodies, tokens or task payload logging.
- A shared actor client owns sync state; the main-actor store owns views and cancels superseded refreshes.
- Query results are deduplicated per refresh when both panels choose the same query. Failure preserves the last complete result with its timestamp and a visible error. A newly selected filter never displays the previous filter's tasks.
- Completing a task invalidates old reads. Only a confirmed completion removes it. Both panels refresh afterwards. Unknown outcomes lock that task's completion action until the user verifies it in Todoist.
- HTTP 429 honors Retry-After. No offline write queue. No disk task cache in v0.1.
- Overdue/today are disjoint calendar-day buckets in the account timezone. Floating and fixed-zone due dates are parsed separately. Counts apply to each selected filter, never to the whole account.

## Delivery stages

1. Research and architecture decision — recorded before implementation.
2. Native project, demo mode, two panels and editable settings.
3. Keychain connection, saved filters, grouped/paginated reads, synchronization, task deep links and completion.
4. Automated core tests and arm64 packaging; manual target-Mac checks and authenticated read/write checks.

## Acceptance checks

Automated: escaped/grouped filters; account timezone dates; full then incremental filter sync; rename/deletion; multi-page reads and deduplication; repeated cursor failure; failed later page; unauthorized response; rate limits; close task request and null response.

Manual, still required: first launch, Keychain save/read/delete, two different real filters, switching during a slow request, real ordinary and recurring completion, failure display, drag/lock/resize, relaunch position persistence, multiple displays, Spaces, Show Desktop, Stage Manager, full screen, sleep/wake, dark/light mode and Reduce Transparency. Real completion tests should use disposable tasks created by the user.

## Primary sources

- [Todoist API v1](https://developer.todoist.com/api/v1/) — Sync resources, filters, tasks by filter, close task, dates, desktop URL schemes.
- [Apple: Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) — WidgetKit timeline budget; typical frequently viewed widget budget 40–70 reloads per day, not a minute timer.
- [Apple: Adding interactivity to widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities) — AppIntent-backed buttons and toggles; completion is possible.
- [Apple: Displaying the right widget background](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background) — removable and system-rendered backgrounds.
- [Apple: Behind-window blending](https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode-swift.enum/behindwindow) — blur of desktop/windows behind an app window.
- [Übersicht project](https://github.com/felixhageloh/uebersicht) — React/CSS widgets and documented interaction requirements.
