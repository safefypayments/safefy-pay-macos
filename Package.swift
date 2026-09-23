// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SafefyPay",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SafefyPay", targets: ["SafefyPay"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(name: "SafefyPay", dependencies: [.product(name: "Sparkle", package: "Sparkle")]),
        .testTarget(name: "SafefyPayTests", dependencies: ["SafefyPay"])
    ]
)
