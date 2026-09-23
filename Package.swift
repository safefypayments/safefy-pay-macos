// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SafefyPay",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SafefyPay", targets: ["SafefyPay"])],
    targets: [
        .executableTarget(name: "SafefyPay"),
        .testTarget(name: "SafefyPayTests", dependencies: ["SafefyPay"])
    ]
)
