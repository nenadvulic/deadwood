// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "deadwood",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "deadwood", targets: ["deadwood"]),
        .library(name: "DeadwoodCore", targets: ["DeadwoodCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(name: "DeadwoodCore"),
        .executableTarget(
            name: "deadwood",
            dependencies: [
                "DeadwoodCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "DeadwoodCoreTests", dependencies: ["DeadwoodCore"]),
    ]
)
