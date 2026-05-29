// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TokenChecker",
    defaultLocalization: "ja",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TokenChecker",
            path: "Sources/TokenChecker",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/Info.plist",
                ])
            ]
        ),
        .testTarget(
            name: "TokenCheckerTests",
            dependencies: ["TokenChecker"],
            path: "Tests/TokenCheckerTests"
        ),
    ]
)
