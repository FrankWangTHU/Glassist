import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Export the approved artwork at every native macOS icon resolution.
// Keep the full-resolution source so regenerating assets preserves the design.
let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
let arguments = Array(CommandLine.arguments.dropFirst())
let root = arguments.first.map { URL(fileURLWithPath: $0) }
    ?? repository.appendingPathComponent("Resources/Assets.xcassets")
let source = arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
    ?? repository.appendingPathComponent("Resources/Branding/Glassist-Frosted-Panes-v1.png")
let folder = root.appendingPathComponent("AppIcon.appiconset")

struct IconExportError: Error, CustomStringConvertible {
    let description: String
}

guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
      let artwork = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
      artwork.width == artwork.height, artwork.width >= 1024 else {
    throw IconExportError(description: "Icon source must be a readable square image of at least 1024 pixels: \(source.path)")
}
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
var entries: [[String: String]] = []

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        guard let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
            bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw IconExportError(description: "Could not allocate the \(pixels)-pixel icon.")
        }
        context.interpolationQuality = .high
        // Apply the app icon's production silhouette at export time. The source
        // remains intact; stray pixels in its transparent padding never reach Dock.
        let factor = CGFloat(pixels) / 1024
        context.scaleBy(x: factor, y: factor)
        context.addPath(CGPath(
            roundedRect: CGRect(x: 66, y: 64, width: 880, height: 884),
            cornerWidth: 218, cornerHeight: 218, transform: nil
        ))
        context.clip()
        context.draw(artwork, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        let destinationURL = folder.appendingPathComponent(name)
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil
              ) else {
            throw IconExportError(description: "Could not create \(name).")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw IconExportError(description: "Could not save \(name).")
        }
        entries.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}

let info: [String: Any] = ["version": 1, "author": "xcode"]
try JSONSerialization.data(withJSONObject: ["images": entries, "info": info], options: [.prettyPrinted, .sortedKeys])
    .write(to: folder.appendingPathComponent("Contents.json"))
try JSONSerialization.data(withJSONObject: ["info": info], options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("Contents.json"))
print("Exported \(entries.count) macOS icons from \(source.lastPathComponent) to \(folder.path)")
