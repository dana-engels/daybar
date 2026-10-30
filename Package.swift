// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Daybar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Daybar", targets: ["Daybar"])],
    targets: [
        .executableTarget(name: "Daybar"),
        .testTarget(name: "DaybarTests", dependencies: ["Daybar"])
    ]
)
