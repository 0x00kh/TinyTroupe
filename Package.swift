// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TinyTroupe",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "TinyTroupe", targets: ["TinyTroupe"]),
    ],
    targets: [
        .target(name: "RunnerCore"),
        .executableTarget(
            name: "TinyTroupe",
            dependencies: ["RunnerCore"],
            path: "Sources/TinyTroupe",
            linkerSettings: [
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "RunnerCoreTests",
            dependencies: ["RunnerCore"]
        ),
    ]
)
