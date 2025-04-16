// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SudoSiteReputation",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "SudoSiteReputation",
            targets: ["SudoSiteReputation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sudoplatform/sudo-api-client-ios", from: "13.0.0"),
        .package(url: "https://github.com/sudoplatform/sudo-config-manager-ios", from: "5.0.0"),
        .package(url: "https://github.com/sudoplatform/sudo-logging-ios", from: "2.0.0"),
        .package(url: "https://github.com/sudoplatform/sudo-user-ios", from: "18.0.0"),
        .package(url: "https://github.com/aws-amplify/amplify-swift", from: "2.45.4")
    ],
    targets: [
        .target(
            name: "SudoSiteReputation",
            dependencies: [
                .product(name: "Amplify", package: "amplify-swift"),
                .product(name: "AWSAPIPlugin", package: "amplify-swift"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift"),
                .product(name: "AWSPluginsCore", package: "amplify-swift"),
                .product(name: "SudoApiClient", package: "sudo-api-client-ios"),
                .product(name: "SudoConfigManager", package: "sudo-config-manager-ios"),
                .product(name: "SudoLogging", package: "sudo-logging-ios"),
                .product(name: "SudoUser", package: "sudo-user-ios")
            ],
            path: "SudoSiteReputation/")
    ]
)
