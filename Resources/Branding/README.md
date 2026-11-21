# Glassist icon

`Glassist-Frosted-Panes-v1.png` is the approved full-resolution artwork: two frosted glass panes and a coral checkmark. Preserve its transparent background and proportions.

From the repository root, run `swift scripts/render-app-icon.swift` to regenerate all ten macOS AppIcon assets at their native sizes (16–1024 pixels). The exporter applies a clean rounded-square silhouette to keep the transparent padding clear, without modifying the master artwork. The Xcode host application uses the resulting `Resources/Assets.xcassets/AppIcon.appiconset`.

The artwork source is not copied into the application bundle. Xcode packages the compiled icon assets.
