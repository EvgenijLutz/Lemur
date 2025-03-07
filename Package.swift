// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Lemur",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Lemur",
            targets: ["Lemur"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        
        // Header files to share uniforms between Metal shaders and Swift
        .target(
            name: "LemurC"
            //cSettings: [
            //    .headerSearchPath("Private")
            //]
        ),
        
        // Main library
        .target(
            name: "Lemur",
            dependencies: ["LemurC"]
            //resources: [
            //    //.copy("main.metal")
            //    //.process("main.metal")
            //]
        ),
    ]
)
