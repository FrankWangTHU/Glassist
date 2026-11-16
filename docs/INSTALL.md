# Install the native WidgetKit version

This is a development project, not a notarized distribution. The unsigned CI package only demonstrates that the host and widget compile. Do not treat it as an installed/registered system widget.

## Requirements

- Apple Silicon Mac with macOS 14 or newer.
- Full Xcode 15 or newer; Command Line Tools alone cannot configure signing and provisioning.
- An Apple account in Xcode. Apple provides a free developer account for personal development. Availability of App Groups and Keychain Sharing depends on the chosen signing team/capabilities. Do not purchase membership solely on the assumption that every local widget requires it; verify the team's capability support in Xcode first.

## Configure on your own Mac

1. Install Xcode from Apple's Mac App Store. Open it and complete its first-run setup yourself.
2. Xcode → Settings → Accounts → sign in to your Apple account locally. Do not send passwords, verification codes or certificates in chat.
3. Open `Glassist.xcodeproj`. For **both** Glassist and GlassistWidgets, select the same team under Signing & Capabilities and enable Automatically manage signing.
4. Register/select the same App Group for both targets. The default is `group.com.frankwang.Glassist`; if unavailable, choose a unique group and set the project build setting `GLASSIST_GROUP_ID` to it. Keep the two entitlements and Info.plist substitutions consistent.
5. Confirm Keychain Sharing on both targets. The shared access group is `$(AppIdentifierPrefix)com.frankwang.Glassist.shared`; Xcode expands the prefix from your actual provisioning profile. Do not type a fake team ID or disable entitlement checks.
6. Build and run the **Glassist** scheme on My Mac. Resolve any signing errors in Xcode before continuing. If your Personal Team cannot provision these capabilities, use a supported development team; paid program enrollment is a separate decision.
7. In Glassist, paste the Todoist token only into its local secure field and connect. This version requires a fresh connection to its shared Keychain group; it does not read another app's token or copy the old prototype's credentials automatically.
8. Click the macOS menu bar date → Edit Widgets → search Glassist → select Small, Medium or Large. Add twice if desired. Right-click each widget → Edit Glassist → choose a filter independently.

Glassist gets its glass/tint appearance from the system widget appearance. It cannot force a blur amount or override Reduce Transparency. Follow system settings to obtain the same look as neighboring Apple widgets.

To remove a widget, use its system context menu. To close the settings window, use the red close button or “关闭设置”; Command-Q quits the settings app. The widget runs separately, under system scheduling.

## Apple developer membership

A free developer account can be created with an Apple account. The paid Apple Developer Program is currently listed at USD 99/year, or CNY 688/year in mainland China's Developer app enrollment flow, with automatic renewal for app enrollment. Identity checks, agreement acceptance and purchase must be completed by the account holder in Apple's interface. No membership or payment has been started by this project.

Official references checked 2026-11-16:

- [Free account and program benefits](https://developer.apple.com/cn/get-started/)
- [Mainland China enrollment](https://developer.apple.com/cn/help/account/membership/enrolling-in-the-app/)
- [macOS capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-macos)
- [App group provisioning](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [Keychain sharing](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps)
