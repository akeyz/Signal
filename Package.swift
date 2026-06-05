// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Signal",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Signal",
            path: "Sources/Signal"
        ),
        .executableTarget(
            name: "sgl",
            path: "Sources/sgl"
        )
    ]
)
