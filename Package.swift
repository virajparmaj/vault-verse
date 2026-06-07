// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VaultVerse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "VaultVerseCore", targets: ["VaultVerseCore"]),
        .executable(name: "vaultverse-demo", targets: ["vaultverse-demo"]),
    ],
    targets: [
        .target(
            name: "VaultVerseCore",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "vaultverse-demo",
            dependencies: ["VaultVerseCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "VaultVerseCoreTests",
            dependencies: ["VaultVerseCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
