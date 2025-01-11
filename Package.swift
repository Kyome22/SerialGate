// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SerialGate",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SerialGate",
            targets: ["SerialGate"]
        )
    ],
    targets: [
        .target(
            name: "SerialGate"
        )
    ]
)
