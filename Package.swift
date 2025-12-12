// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
// Note: This Package.swift is primarily for Swift extension test discovery.
// The main project builds via Xcode workspace.

import PackageDescription

let package = Package(
    name: "Planetary",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)  // Required for CryptoKit.SHA256
    ],
    products: [
        // Products are defined here for Swift extension discovery
    ],
    dependencies: [
        // No external dependencies needed for IdentifierTests
    ],
    targets: [
        // Source target for Identifier model
        .target(
            name: "PlanetaryModel",
            dependencies: [],
            path: "Source/Model",
            sources: [
                "Identifier.swift"
            ]
        ),
        // Test target for Swift Testing framework discovery
        .testTarget(
            name: "UnitTests",
            dependencies: [
                "PlanetaryModel",
            ],
            path: "UnitTests",
            exclude: [
                "Resources",
                "Performance",
                "Test Helpers",
                "Controller",
                "Service",
                "Performance Tests.xctestplan",
                "Planetary Unit Tests.xctestplan",
                "Model/AppConfigurationTests.swift",
                "Model/AttributedStringTests.swift",
                "Model/BlobTests.swift",
                "Model/DateTests.swift",
                "Model/EncodeJSONtest.swift",
                "Model/MarkdownTests.swift",
                "Model/MultiserverAddressTests.swift",
                "Model/NetworkKeyTests.swift",
                "Model/SecretTests.swift",
            ],
            sources: [
                "Model/IdentifierTests.swift"
            ]
        )
    ]
)

