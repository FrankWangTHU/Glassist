import AppKit

// Original vector artwork, rendered at each native macOS icon resolution.
// Two independent glass panes echo Glassist's independently configured widgets.
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/Assets.xcassets")
let folder = root.appendingPathComponent("AppIcon.appiconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
var entries: [[String: String]] = []
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
func artwork() {
    let tile = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 198, yRadius: 198)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = color(0.18, 0.23, 0.28, 0.18)
    shadow.shadowBlurRadius = 32; shadow.shadowOffset = NSSize(width: 0, height: -14); shadow.set()
    color(0.94, 0.95, 0.96).setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [color(1, 0.98, 0.95), color(0.83, 0.88, 0.91)])!.draw(in: tile, angle: -65)
    color(1, 1, 1, 0.9).setStroke(); tile.lineWidth = 4; tile.stroke()
    func pane(_ rect: NSRect, coral: Bool) {
        NSGraphicsContext.saveGraphicsState()
        let shade = NSShadow(); shade.shadowColor = color(0.18, 0.22, 0.27, 0.19)
        shade.shadowBlurRadius = 25; shade.shadowOffset = NSSize(width: 0, height: -16); shade.set()
        let shape = NSBezierPath(roundedRect: rect, xRadius: 58, yRadius: 58)
        color(1, 1, 1, 0.8).setFill(); shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        let colors = coral ? [color(1, 0.49, 0.38), color(0.88, 0.24, 0.22)] : [color(1, 1, 1, 0.96), color(0.9, 0.94, 0.96, 0.83)]
        NSGradient(colors: colors)!.draw(in: shape, angle: -90)
        color(1, 1, 1, 0.75).setStroke(); shape.lineWidth = 3; shape.stroke()
        let ink = coral ? color(1, 1, 1, 0.95) : color(0.55, 0.65, 0.69, 0.9)
        for row in 0..<3 {
            let y = rect.maxY - 100 - CGFloat(row) * 93
            ink.setStroke()
            let mark = NSBezierPath(ovalIn: NSRect(x: rect.minX + 37, y: y - 15, width: 30, height: 30))
            mark.lineWidth = 5; mark.stroke()
            ink.withAlphaComponent(coral ? 0.84 : 0.55).setFill()
            NSBezierPath(roundedRect: NSRect(x: rect.minX + 89, y: y - 7, width: row == 2 ? 98 : 132, height: 14), xRadius: 7, yRadius: 7).fill()
        }
    }
    pane(NSRect(x: 181, y: 299, width: 310, height: 435), coral: false)
    pane(NSRect(x: 457, y: 218, width: 358, height: 483), coral: true)
    let ring = NSBezierPath(ovalIn: NSRect(x: 682, y: 625, width: 151, height: 151))
    color(1, 1, 1).setFill(); ring.fill()
    let check = NSBezierPath(); check.move(to: NSPoint(x: 721, y: 701)); check.line(to: NSPoint(x: 747, y: 675)); check.line(to: NSPoint(x: 792, y: 727))
    check.lineWidth = 14; check.lineCapStyle = .round; check.lineJoinStyle = .round
    color(0.87, 0.25, 0.22).setStroke(); check.stroke()
}
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
        artwork(); NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
        entries.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
let metadata: [String: Any] = ["images": entries, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("Contents.json"))
try JSONSerialization.data(withJSONObject: ["info": ["version": 1, "author": "xcode"]]).write(to: root.appendingPathComponent("Contents.json"))
print("Rendered macOS AppIcon assets at \(folder.path)")
