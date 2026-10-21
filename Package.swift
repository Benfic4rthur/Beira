// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Beira",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Beira", targets: ["Beira"])],
    targets: [
        .target(name: "BeiraCore"),
        .target(name: "TrackpadBridge", linkerSettings: [.linkedFramework("CoreFoundation")]),
        .executableTarget(name: "Beira", dependencies: ["BeiraCore", "TrackpadBridge"]),
        .testTarget(name: "BeiraCoreTests", dependencies: ["BeiraCore"])
    ],
    swiftLanguageModes: [.v5]
)
