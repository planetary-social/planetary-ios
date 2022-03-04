// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Analytics",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Analytics",
            targets: ["Analytics"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "Logger",
                 path: "../Logger"),
        .package(name: "Secrets",
                 path: "../Secrets"),
        .package(name: "PostHog",
                 url: "https://github.com/PostHog/posthog-ios",
                 from: "1.4.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Analytics",
            dependencies: ["Logger", "Secrets", "PostHog"],
            path: "Sources"),
        .testTarget(
            name: "AnalyticsTests",
            dependencies: ["Analytics"],
            path: "Tests",
            resources: [.copy("Samples/Secrets.plist")]),
    ]
)
