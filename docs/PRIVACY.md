# Glassist privacy policy

Effective November 17, 2026. Applies to Glassist 0.3.2.

Glassist is an independent macOS application that displays your saved Todoist filters in native widgets. It connects directly to Todoist. The project does not operate a server that receives your account credentials or tasks.

## Data used by the app

- Your Todoist API token authenticates requests to Todoist. You enter it in the app's local secure field. It is stored in the macOS data-protection Keychain, shared only with the signed Glassist app and widget extension through their configured access group. The stored item is marked for this device only.
- Saved filter names, IDs, queries and ordering are retrieved to populate the filter selector.
- Matching tasks can include IDs, titles, priority, due dates, recurrence information and completion state. The app caches these fields locally for widget display and synchronization.
- Todoist language and time-zone settings support filter interpretation and date display. Glassist also stores interface preferences, sync times, retry state and completion feedback locally.

Version 0.3.2 ignores task descriptions and other unused task fields. Reading and rewriting a pre-0.3.2 cache removes previously stored descriptions from the active cache; backups are outside this cleanup.

The task cache is a JSON file in the app's shared macOS container, protected by local file permissions. It is separate from the Keychain credential and is not encrypted by Glassist itself. macOS also manages widget configurations and rendered widget content.

## Network requests and sharing

Glassist sends authenticated HTTPS requests directly to `api.todoist.com` to read saved filters and matching tasks, and to complete a task when you click its completion control. Opening a task or using Quick Add passes the corresponding route to the installed Todoist app. Quick Add submission is handled by Todoist.

Glassist has no advertising SDK, analytics service or developer-operated task storage. The project does not sell your data or share it with unrelated third parties. Todoist processes requests according to its own [privacy policy](https://www.todoist.com/privacy). Apple, operating-system backups and any services you use to share screenshots or diagnostics are governed by their own settings and policies.

## Retention and disconnecting

Local snapshots are retained so widgets can display cached content. They are replaced on refresh; snapshots for removed filters are cleared when the catalog updates. Choosing **Disconnect** in Glassist deletes its saved Keychain token and resets the shared account and task cache, retaining your interface-language preference. This does not delete your Todoist tasks or revoke the token in Todoist. You can manage or reset your token in Todoist itself.

Removing a widget or deleting the app alone is not a promise that macOS has erased all local containers, backups or rendered snapshots. Disconnect in the app first when you want to clear Glassist's active account cache.

## Support and changes

For questions, open an issue in the [Glassist repository](https://github.com/FrankWangTHU/Glassist/issues). Issues are public: do not include API tokens, passwords or private task content. If you voluntarily share a diagnostic file or screenshot, inspect it first. Future releases that change data handling will update this policy.

Glassist is not created by, affiliated with, or supported by Todoist.
