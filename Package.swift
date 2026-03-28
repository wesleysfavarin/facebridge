// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FaceBridge",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "FaceBridgeCore", targets: ["FaceBridgeCore"]),
        .library(name: "FaceBridgeCrypto", targets: ["FaceBridgeCrypto"]),
        .library(name: "FaceBridgeProtocol", targets: ["FaceBridgeProtocol"]),
        .library(name: "FaceBridgeTransport", targets: ["FaceBridgeTransport"]),
        .library(name: "FaceBridgeSharedUI", targets: ["FaceBridgeSharedUI"]),
    ],
    targets: [
        // MARK: - Core

        .target(
            name: "FaceBridgeCore",
            dependencies: []
        ),

        // MARK: - Crypto

        .target(
            name: "FaceBridgeCrypto",
            dependencies: ["FaceBridgeCore"]
        ),

        // MARK: - Protocol

        .target(
            name: "FaceBridgeProtocol",
            dependencies: ["FaceBridgeCore"]
        ),

        // MARK: - Transport

        .target(
            name: "FaceBridgeTransport",
            dependencies: ["FaceBridgeCore", "FaceBridgeProtocol"]
        ),

        // MARK: - Shared UI

        .target(
            name: "FaceBridgeSharedUI",
            dependencies: ["FaceBridgeCore", "FaceBridgeProtocol"]
        ),

        // MARK: - iOS App

        .target(
            name: "FaceBridgeiOSApp",
            dependencies: [
                "FaceBridgeCore",
                "FaceBridgeCrypto",
                "FaceBridgeProtocol",
                "FaceBridgeTransport",
                "FaceBridgeSharedUI",
            ]
        ),

        // MARK: - macOS App

        .target(
            name: "FaceBridgeMacApp",
            dependencies: [
                "FaceBridgeCore",
                "FaceBridgeCrypto",
                "FaceBridgeProtocol",
                "FaceBridgeTransport",
                "FaceBridgeSharedUI",
            ]
        ),

        // MARK: - macOS Agent

        .target(
            name: "FaceBridgeMacAgent",
            dependencies: [
                "FaceBridgeCore",
                "FaceBridgeCrypto",
                "FaceBridgeProtocol",
                "FaceBridgeTransport",
            ]
        ),

        // MARK: - Tests

        .testTarget(
            name: "FaceBridgeCoreTests",
            dependencies: ["FaceBridgeCore"]
        ),
        .testTarget(
            name: "FaceBridgeCryptoTests",
            dependencies: ["FaceBridgeCrypto", "FaceBridgeCore"]
        ),
        .testTarget(
            name: "FaceBridgeProtocolTests",
            dependencies: ["FaceBridgeProtocol", "FaceBridgeCore"]
        ),
        .testTarget(
            name: "FaceBridgeTransportTests",
            dependencies: ["FaceBridgeTransport", "FaceBridgeCore", "FaceBridgeProtocol"]
        ),
    ]
)
