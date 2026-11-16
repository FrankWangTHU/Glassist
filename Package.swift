// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Glassist", platforms: [.macOS(.v14)],
    products: [.executable(name: "Glassist", targets: ["Glassist"])],
    targets: [.target(name: "GlassistCore"),
              .executableTarget(name: "Glassist", dependencies: ["GlassistCore"]),
              .testTarget(name: "GlassistCoreTests", dependencies: ["GlassistCore"])])
