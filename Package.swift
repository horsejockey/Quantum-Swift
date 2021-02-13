// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Reactor",
    products: [
        .library(
            name: "Reactor",
            targets: ["Reactor"]),
    ],
    dependencies: [
         .package(
             name: "PureStateMachine",
             url: "https://github.com/horsejockey/PureStateMachine-Swift",
             from: "1.0.0"
        ),
         .package(
             name: "MessageRouter",
             url: "https://github.com/horsejockey/MessageRouter-iOS",
             from: "2.0.0"
        ),
    ],
    targets: [
        .target(
            name: "Reactor",
            dependencies: ["PureStateMachine", "MessageRouter"]),
        .testTarget(
            name: "ReactorTests",
            dependencies: ["Reactor"]),
    ]
)
