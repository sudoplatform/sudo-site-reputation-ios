// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SudoSiteReputation",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "SudoSiteReputation",
            targets: ["SudoSiteReputation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sudoplatform/sudo-api-client-ios", from: "12.0.0"),
        .package(url: "https://github.com/sudoplatform/sudo-logging-ios", from: "2.0.0"),
        .package(url: "https://github.com/sudoplatform/sudo-user-ios", from: "17.0.3"),
        .package(url: "https://github.com/aws-amplify/aws-sdk-ios-spm", exact: "2.36.7"),
        .package(url: "https://github.com/typealiased/mockingbird", .upToNextMinor(from: "0.20.0")),
    ],
    targets: [
        .target(
            name: "SudoSiteReputation",
            dependencies: [
                .product(name: "AWSCore", package: "aws-sdk-ios-spm"),
                .product(name: "AWSS3", package: "aws-sdk-ios-spm"),
                .product(name: "SudoApiClient", package: "sudo-api-client-ios"),
                .product(name: "SudoLogging", package: "sudo-logging-ios"),
                .product(name: "SudoUser", package: "sudo-user-ios")
            ],
            path: "SudoSiteReputation/")
    ]
)

