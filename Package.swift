// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EchoFlow",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "EchoFlow",
            path: "Sources"
        )
    ]
)
