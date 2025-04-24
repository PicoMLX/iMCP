// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iMCP",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "iMCP",
            targets: ["iMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/loopwork-ai/mcp-swift-sdk", from: "0.7.1"),
        .package(url: "https://github.com/loopwork-ai/Ontology", from: "0.6.0"),
        .package(url: "https://github.com/orchetect/MacControlCenterUI", from: "2.4.1"),
    ],
    targets: [    
        .target(
            name: "iMCP",
            dependencies: [
                .product(name: "MCP", package: "mcp-swift-sdk"),
                .product(name: "Ontology", package: "Ontology"),
                .product(name: "MacControlCenterUI", package: "MacControlCenterUI"),
            ],
            resources: [
//                .process("Localizable.xcstrings"),
//                .copy("Resources/models.json"),
            ]
        ),

    ]
)
