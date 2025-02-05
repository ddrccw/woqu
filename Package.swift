// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "woqu",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "woqu",
            targets: ["woqu"]),
        .library(
            name: "WoquCore",
            targets: ["WoquCore"]),
        .library(
            name: "WoquCLI",
            targets: ["WoquCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "woqu",
            dependencies: [
                "WoquCLI",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/Woqu"
        ),
        .target(
            name: "WoquCore",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/WoquCore"
        ),
        .target(
            name: "WoquCLI",
            dependencies: [
                "WoquCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/WoquCLI"
        ),
//        .testTarget(
//            name: "WoquTests",
//            dependencies: ["WoquCore"])
    ]
)
