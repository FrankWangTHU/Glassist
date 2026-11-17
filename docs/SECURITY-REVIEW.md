# Security review — November 17, 2026

Scope: Glassist source, local installation and renewal scripts, CI configuration, repository history through `eb08210`, and the prepared Todoist submission assets. This is a focused engineering review, not an independent penetration test or a guarantee that all vulnerabilities have been found.

## Findings and changes in 0.3.2

- **Reduce locally retained data.** Widgets did not display task descriptions, but 0.3.1 decoded and cached them. Version 0.3.2 ignores that field. Reading and rewriting an existing cache removes previously stored descriptions from the active file. This does not erase operating-system backups.
- **Validate retry metadata.** A non-finite or overflowing `Retry-After` value could reach an integer conversion used in error text. Invalid values now use a finite fallback, with regression tests covering malformed headers.
- **Pin CI dependencies.** The checkout and artifact-upload actions are pinned to immutable commit IDs. Checkout no longer leaves its temporary GitHub credential in the working copy. Workflow permissions remain read-only; published build artifacts are unsigned.

## Checks performed

- Inspected all 12 reachable commits and 89 distinct text blobs at the review baseline. Pattern-based scanning found no candidate literal API tokens, private keys or password assignments, and no tracked local signing files, provisioning profiles or cached account databases. Pattern matching cannot identify every possible secret format.
- Reviewed the committed media. The connection field is empty in the recording and screenshots. The recording includes account task titles; publication of those titles is separate from credential handling. JPG submission images contain no EXIF fields.
- Verified that authenticated requests use a fixed HTTPS Todoist API origin, redirect following is disabled, response bodies are not exposed in app error messages, and requests use an ephemeral session without a disk URL cache. There is no custom TLS trust bypass.
- Verified that the token is separate from the task cache, in the data-protection Keychain with the app/extension access group and device-only accessibility. The secure entry field is cleared when a connection is attempted.
- Reviewed the URL-route allowlist. External routes can open settings, Todoist or a task/filter; they cannot issue completion/deletion requests or forward an arbitrary URL. Task completion validates IDs, requires a recent cached task and matching account generation, blocks repeated uncertain requests, and routes recurring tasks back to Todoist.
- Reviewed sandbox entitlements: the app and extension request their shared container/Keychain group and outgoing network access, without microphone, camera, screen-recording, accessibility or broad file-access entitlements. The separate development walkthrough recorder is not part of the distributed app.
- Confirmed the package has no third-party runtime dependencies. Test fixtures use dummy credentials. A signed Apple Silicon build and 27 Swift tests plus 8 renewal-helper tests passed locally.

## Remaining boundaries

The local task-title cache is protected by file permissions, not app-level encryption. macOS manages widget snapshots and backups. A personal API token is powerful; never put it in a public issue, repository or submission form. A compromised Mac or compromised Todoist account is outside the protections of this widget.

The submission must identify the app as a source-build developer preview using temporary Personal Team signing. It must not claim Developer ID distribution, notarization, Todoist certification or a complete third-party security audit. The public walkthrough was recorded with 0.3.1; 0.3.2 changes cache minimization and robustness without changing that demonstrated workflow.
