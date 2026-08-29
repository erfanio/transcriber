// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TranscribeCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TranscribeCore", targets: ["TranscribeCore"]),
    ],
    targets: [
        .target(
            name: "TranscribeCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TranscribeCoreTests",
            dependencies: ["TranscribeCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
