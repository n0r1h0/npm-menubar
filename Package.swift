// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NpmMenuBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NpmMenuBar",
            path: "Sources/NpmMenuBar"
        )
    ]
)
