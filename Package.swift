// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Quantum",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "Quantum",
            targets: ["Quantum"]),
    ],
    dependencies: [
         .package(
             name: "PureStateMachine",
             url: "https://github.com/horsejockey/PureStateMachine-Swift",
             from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "Quantum",
            dependencies: ["PureStateMachine"]),
        .testTarget(
            name: "QuantumTests",
            dependencies: ["Quantum"]),
    ]
)
