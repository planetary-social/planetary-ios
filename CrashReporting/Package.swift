// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CrashReporting",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CrashReporting",
            targets: ["CrashReporting"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            name: "Bugsnag",
            url: "https://github.com/bugsnag/bugsnag-cocoa",
            from: "6.9.5"
        ),
        .package(
            name: "Logger",
            path: "../Logger"
        ),
        .package(
            name: "Secrets",
            path: "../Secrets"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CrashReporting",
            dependencies: ["Bugsnag", "Logger", "Secrets"],
            path: "Sources"
        ),
        .testTarget(
            name: "CrashReportingTests",
            dependencies: ["CrashReporting"],
            path: "Tests",
            resources: [.copy("Samples/Secrets.plist")]
        )
    ]
)
