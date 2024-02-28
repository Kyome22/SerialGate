// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SerialGate",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "SerialGate",
            targets: ["SerialGate"]
        )
    ],
    targets: [
        .target(name: "SerialGate")
    ]
)
