// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "persistent-collections",
    products: [
        .library(
            name: "persistent-collections",
            targets: ["persistent-collections"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pumperknickle/Bedrock.git", from: "0.2.4"),
        .package(url: "https://github.com/Quick/Quick.git", from: "3.1.2"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "9.0.0"),
    ],
    targets: [
        .target(
            name: "persistent-collections",
            dependencies: ["Bedrock"]),
        .testTarget(
            name: "persistent-collectionsTests",
            dependencies: ["persistent-collections", "Quick", "Nimble", "Bedrock"]),
    ]
)
