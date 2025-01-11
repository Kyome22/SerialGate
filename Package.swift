// swift-tools-version: 6.0

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "SerialGate",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Logput",
            targets: ["Logput"]
        ),
        .library(
            name: "SerialGate",
            targets: ["SerialGate"]
        ),
    ],
    targets: [
        .target(
            name: "Logput",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SerialGate",
            dependencies: ["Logput"],
            swiftSettings: swiftSettings
        )
    ]
)
