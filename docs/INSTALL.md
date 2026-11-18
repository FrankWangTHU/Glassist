# Install the native WidgetKit version

This is a development project, not a notarized distribution. The unsigned CI package only demonstrates that the host and widget compile. Do not treat it as an installed/registered system widget.

## Requirements

- Apple Silicon Mac with macOS 14 or newer.
- Full Xcode 15 or newer; Command Line Tools alone cannot configure signing and provisioning.
- An Apple account in Xcode. Apple's current macOS capabilities table explicitly lists App Groups and Keychain Sharing for the free Apple Developer account (an Apple Account holder who accepted the Developer Agreement). Start with the free Personal Team for this self-use build; paid membership is not a prerequisite established by this project. Local provisioning and installation still need verification.

## Configure on your own Mac

1. Install Xcode from Apple's Mac App Store. Open it and complete its first-run setup yourself.
2. Xcode → Settings → Accounts → sign in to your Apple account locally. Do not send passwords, verification codes or certificates in chat.
3. Copy `Configuration/LocalSigning.xcconfig.example` to `Configuration/LocalSigning.xcconfig` and enter the Team ID shown in Xcode. This ignored local file sets the same team for **both** Glassist and GlassistWidgets. Open `Glassist.xcodeproj`; automatic signing is already enabled. Alternatively, choose the same team on both targets in Signing & Capabilities.
4. The shared App Group defaults to `$(DEVELOPMENT_TEAM).com.frankwang.Glassist`, using Apple's supported macOS team-prefixed naming convention. Both targets inherit it from `Configuration/Signing.xcconfig`. This matches the team's macOS provisioning wildcard without separately registering a `group.*` identifier. Keep the two entitlements and Info.plist substitutions consistent; changing the group creates a different data container.
5. Confirm Keychain Sharing on both targets. The shared access group is `$(AppIdentifierPrefix)com.frankwang.Glassist.shared`; Xcode expands the prefix from your actual provisioning profile. Do not type a fake team ID or disable entitlement checks.
6. Run `bash scripts/install-local.sh` from the repository to build, verify the signature and install to `/Applications/Glassist.app`. It replaces only an existing Glassist app, preserves account data in its separate shared container, and closes/reopens the settings app. An optional absolute destination supports `~/Applications` after shell expansion; `--build-only` verifies a signed build without installing. You can also build and run the **Glassist** scheme on My Mac in Xcode. If macOS asks whether codesign may use the development certificate, authorize it in the system dialog. Do not send your Mac password in chat. Resolve signing errors before continuing.
7. In Glassist, paste the Todoist token only into its local secure field and connect. This version requires a fresh connection to its shared Keychain group; it does not read another app's token or copy the old prototype's credentials automatically.
8. Click the macOS menu bar date → Edit Widgets → search Glassist → select Small, Medium or Large. Add twice if desired. Right-click each widget → Edit Glassist → choose a filter independently.

For the manual Xcode/Finder installation route: select the **Glassist** scheme and **My Mac**, then choose **Product → Build**. After **Build Succeeded**, choose **Product → Show Build Folder in Finder**, open **Products → Debug**, and copy **Glassist.app** into **Applications**. Quit a running Glassist before replacing it, then open the installed copy. The app and embedded widget must both be signed by the same team. If the gallery keeps showing an older version, use `scripts/install-local.sh` to refresh the installed registration and remove the duplicate build-product registration.

Glassist gets its glass/tint appearance from the system widget appearance. It cannot force a blur amount or override Reduce Transparency. Follow system settings to obtain the same look as neighboring Apple widgets.

## Local validation and renewal

On 2026-11-17, the Apple Silicon build was tested with Xcode 27.2: all 24 core tests passed, both targets were signed by a free Personal Team, signature validation passed, the app was installed, macOS registered its widget extension, and the app created its shared container successfully. The user also confirmed Todoist connection and supplied a screenshot of the native Notification Center widget displaying their filter tasks and overdue/today counts. A subsequent live walkthrough verified native Quick Add, task-detail routing and completion of a newly created demo task, including list/count updates. Chinese/English switching and the native widget configuration editor were also checked. All appearance combinations and the minimum macOS version have not been exhaustively tested.

The development profiles generated in that verification expire after seven days. Treat this as a local development installation, not a permanent distribution. Run `bash scripts/install-local.sh` again with the Xcode account signed in to request current profiles, rebuild and reinstall before/when the installation expires. No source download or account reset is needed. Team selection remains local, and no signing credentials are committed.

The subsequent 0.3.2 security update passed 27 core tests and 8 renewal-helper tests, a signed local build and GitHub CI. It was installed on the same Mac, where the existing account and filter connection remained available. See the [focused security review](SECURITY-REVIEW.md) for the scope and remaining limits.

For scheduled maintenance, run `python3 scripts/renew-local-signing.py --renew` daily on this Mac. Without `--renew`, the script only reports the installed deadline. It skips builds until either the app or widget profile has less than 48 hours remaining, asks Xcode to manage signing, and verifies that the earliest expiry across the two profiles has advanced beyond both the installed deadline and the 48-hour window, and that the signing team is unchanged before replacing the app. A successful build with an old profile is not reported as a successful renewal. If Apple reuses an unexpired profile, retry later; if sign-in, Keychain authorization or network access is needed, resolve it in Xcode. Local build logs stay in the ignored `.build/renewal` directory. The script does not install a scheduler itself. If scheduled with Codex, the Mac and Codex need to be running at the scheduled time; it is best-effort maintenance, not guaranteed unattended Apple provisioning.

To remove a widget, use its system context menu. To close the settings window, use the red close button or “关闭设置”; Command-Q quits the settings app. The widget runs separately, under system scheduling.

## Apple developer membership

A free developer account can be created with an Apple account. The paid Apple Developer Program is currently listed at USD 99/year, or CNY 688/year in mainland China's Developer app enrollment flow, with automatic renewal for app enrollment. Identity checks, agreement acceptance and purchase must be completed by the account holder in Apple's interface. No membership or payment has been started by this project.

Official references checked 2026-11-16:

- [Free account and program benefits](https://developer.apple.com/cn/get-started/)
- [Mainland China enrollment](https://developer.apple.com/cn/help/account/membership/enrolling-in-the-app/)
- [macOS capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-macos)
- [App group provisioning](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [Keychain sharing](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps)

## Customize and switch languages

The installer stops the host and its independently running widget extension when updating, then registers the installed copy and unregisters Xcode's duplicate build product. This prevents a stale extension process from referencing a replaced executable and leaving the gallery on placeholder previews. It preserves the shared account data and existing widget configurations. Keep older prototype apps closed; open the copy in Applications.

Open Glassist settings and use **Language / 界面语言** to choose Simplified Chinese, English or the system language. The setting updates the app immediately and requests widget reloads. Right-click each widget → Edit Glassist for an independent filter, title, accent, density, date/count/footer settings and language override. The system editor itself follows the Mac’s language.

Click the widget title or background to open its Todoist filter, a task title for task details, and the top-right plus for the Mac Quick Add window. Ordinary completion is a toggle: the checkmark is optimistic while the request runs, and removal occurs after confirmation. If a request’s result is uncertain, the task remains with a warning and opens Todoist for checking. Recurring tasks always open Todoist.
