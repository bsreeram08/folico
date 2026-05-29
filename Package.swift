// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Folico",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Folico", targets: ["Folico"])
    ],
    targets: [
        .target(
            name: "FolicoApp",
            path: "Sources/FolicoApp"
        ),
        .executableTarget(
            name: "Folico",
            dependencies: ["FolicoApp"],
            path: "Sources/Folico"
        ),
        .testTarget(
            name: "FolicoAppTests",
            dependencies: ["FolicoApp"],
            path: "Tests/FolicoAppTests"
        )
    ]
)
