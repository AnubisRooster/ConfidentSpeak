// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConfidentSpeak",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.0"),
        .package(url: "https://github.com/AnubisRooster/OnDeviceKit", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "ConfidentSpeak",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "BYOKLLMKit", package: "OnDeviceKit"),
            ],
            path: "ConfidentSpeak"
        ),
        .testTarget(
            name: "ConfidentSpeakTests",
            dependencies: ["ConfidentSpeak"],
            path: "ConfidentSpeakTests"
        ),
    ]
)
