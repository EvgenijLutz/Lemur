// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Lemur",
    platforms: [
        .macOS(.v14),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Lemur",
            targets: ["Lemur"]
        ),
    ],
    targets: [
        // Header files to share uniforms between Metal shaders and Swift
        .target(
            name: "LemurC"
        ),
        // Main library
        .target(
            name: "Lemur",
            dependencies: ["LemurC"]
        ),
    ]
)
