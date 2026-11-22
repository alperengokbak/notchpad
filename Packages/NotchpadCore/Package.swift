// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchpadCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "NotchpadCore", targets: ["NotchpadCore"])],
    targets: [
        .target(name: "NotchpadCore"),
        .testTarget(name: "NotchpadCoreTests", dependencies: ["NotchpadCore"], resources: [.copy("Fixtures")]),
    ]
)
