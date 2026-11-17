# Distribution readiness

Glassist 0.3.1 is a public development project. It has been built and used on an Apple Silicon Mac with a local Personal Team signature. There is no notarized, ready-to-install public release yet. CI archives are unsigned build artifacts.

## Local use

Follow [INSTALL.md](INSTALL.md) to build with your own Xcode account. Personal Team provisioning is temporary; the renewal helper checks the deadline and only attempts rebuilding near expiration. It does not download new source or bypass Apple's signing requirements.

## Public release work still required

1. Configure distribution signing for the app and extension. For direct downloads, use Developer ID and Apple's notarization workflow; test the exported app on a clean Mac. A local Personal Team installation does not establish that the public-distribution path works.
2. Publish the verified installation package, version and checksum over HTTPS. Keep the documented source-build route accurate until that package exists.
3. Adopt and install a consistent app icon before capturing final release marketing assets.
4. Choose a source-code license before presenting the project as licensed open-source software. The repository currently contains no license grant; public visibility alone does not supply one.
5. Test onboarding from a disconnected state, multiple saved filters, all widget sizes, offline recovery and the minimum supported macOS version. Existing tests and a single-machine walkthrough do not replace those release checks.

## Optional Todoist certification

The [official submission guide](https://www.todoist.com/help/todoist/integrations/market-your-todoist-integration-B6C5sCKkn) links the [English submission form](https://todoist.typeform.com/to/Vvq7kNcl). It requests a description, setup instructions, website/privacy links, a 250 × 250 white-background JPG icon, 1600 × 1000 JPG screenshots and a setup/use walkthrough. A native app must have a trusted signature. Submission is optional; certification is not needed to share an API integration.

Current public links:

- Project: https://github.com/FrankWangTHU/Glassist
- Setup: https://github.com/FrankWangTHU/Glassist/blob/main/docs/INSTALL.md
- Privacy: https://github.com/FrankWangTHU/Glassist/blob/main/docs/PRIVACY.md
- Support: https://github.com/FrankWangTHU/Glassist/issues

The project's native desktop presentation, independent per-widget filter and appearance controls, and bilingual UI are the intended value proposition. Approval is Todoist's decision, particularly because Todoist also provides widgets of its own. Do not imply certification before it is granted.

Successful certification may include an integration listing, marketing support and Pro coupons. The official guide does not specify a cash payment or coupon duration. It targets an initial review within ten business days.

References checked November 17, 2026: [Todoist submission guide](https://www.todoist.com/help/todoist/integrations/market-your-todoist-integration-B6C5sCKkn), [Apple account overview](https://developer.apple.com/help/account/basics/about-your-developer-account), [Developer ID distribution](https://developer.apple.com/developer-id/).
