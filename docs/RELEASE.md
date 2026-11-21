# Release workflow

This is a release preparation guide, not a claim that a signed installer or an App Store listing is available. Version 0.4.0 (build 7) is a candidate. Production signing, notarization, clean-Mac installation and store submission remain unverified.

## Build and distribute

1. Confirm that the Apple Developer Program membership is active. In Xcode → Settings → Apple Accounts, refresh the account and select the paid team for both targets. Preserve the existing shared-container and Keychain configuration. If the paid Team ID differs from the development team, verify data migration and reconnect through the app; never bypass Keychain access controls or copy credentials into the package.
2. Run `swift test` and `python3 -m unittest discover -s scripts/tests`. Inspect the English onboarding, native filter picker, all widget sizes and disconnected/offline states. The system configuration editor uses the Mac's preferred language, separately from the content-language setting.
3. Run `python3 scripts/release.py archive --team YOUR_TEAM_ID`. The archive is kept in `.build/release/Glassist.xcarchive`. Existing archives are not overwritten.
4. Open the archive in Xcode Organizer and choose **Distribute App → Developer ID → Upload** (or the equivalent direct-distribution option in the installed Xcode). Use automatic signing with the active paid team. Wait for Apple notarization to succeed, then export the notarized app. Credentials stay in Xcode/Keychain.
5. Alternatively, `python3 scripts/release.py export --team YOUR_TEAM_ID --channel developer-id` creates a signed local export. That command alone does not notarize it. Complete notarization and staple the ticket before packaging.
6. Run `python3 scripts/release.py package --team YOUR_TEAM_ID --app /absolute/path/Glassist.app`. It checks both signatures, team, hardened runtime, timestamp, entitlements, profile expiry, embedded privacy manifests, stapled ticket and Gatekeeper approval before creating a ZIP with SHA-256 and a verification receipt in `dist/`. A development-signed app cannot pass this gate.
7. Download that ZIP from its proposed HTTPS release location on another Apple Silicon Mac. Test ordinary Finder installation and first launch with Gatekeeper enabled, connect a test Todoist account, add a widget and select a saved filter. Check task opening, completion of a test task and Quick Add. Do not mark this test complete based only on a local signature check.
8. Publish the verified ZIP and checksum, replace the development-only introduction in INSTALL.md with the matching download/install instructions, and record the final English walkthrough using exactly that build. Never publish raw footage containing credentials.

## Mac App Store

1. Use the same source and bundle IDs. Export a separate App Store build with `python3 scripts/release.py export --team YOUR_TEAM_ID --channel app-store-connect`, or use Organizer → Distribute App → App Store Connect. Developer ID and App Store signatures are separate distribution channels.
2. Create the macOS app record for `com.frankwang.Glassist`, with English and Simplified Chinese metadata, Productivity category, and a free price unless the owner changes that decision. Choose territories through the portal after checking applicable requirements.
3. Prepare final screenshots from the release app at an accepted 16:10 size (1280×800, 1440×900, 2560×1600 or 2880×1800). Existing Todoist submission screenshots are 1600×1000, which is not an accepted Mac App Store screenshot size.
4. Complete App Privacy from the actual data flows, including Todoist's handling of API requests. The bundled privacy manifest declares the required reason for app-local UserDefaults and no tracking; it does not replace App Store Connect's privacy questionnaire.
5. Provide an independent, active Todoist review account or an accepted fully featured review mode. Never submit the owner's personal Todoist token as a review credential. Add the review contact details privately in App Store Connect; do not commit credentials or personal phone numbers.
6. Verify the uploaded build, privacy answers, age rating, export compliance and review access. Submit only after these are complete. App Store approval and Todoist directory review are separate decisions.

## Todoist ticket 956227

Sergio's November 19, 2026 reply withdrew the feature-overlap objection: native Todoist Mac widgets cannot choose saved filters. The remaining request is a Developer ID-signed, notarized download with matching installation instructions, plus a new English recording showing installation and explicit selection of a saved filter for a widget. The previous recording of an already-selected filter is insufficient for this step.

References: [Apple direct distribution](https://developer.apple.com/developer-id/), [App Review](https://developer.apple.com/app-store/review/guidelines/), [Mac screenshot sizes](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/), [App Privacy](https://developer.apple.com/app-store/app-privacy-details/).
