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
            targets: ["iMCP"]
        ),
        .executable(
            name: "mcp-server",
            targets: ["mcp-server"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/loopwork-ai/mcp-swift-sdk", from: "0.7.1"),
        .package(url: "https://github.com/loopwork-ai/Ontology", from: "0.6.0"),
        .package(url: "https://github.com/orchetect/MacControlCenterUI", from: "2.4.1"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "2.7.0")
    ],
    targets: [    
        .target(
            name: "iMCP",
            dependencies: [
                .product(name: "MCP", package: "mcp-swift-sdk"),
                .product(name: "Ontology", package: "Ontology"),
                .product(name: "MacControlCenterUI", package: "MacControlCenterUI"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            resources: [
//                .process("Localizable.xcstrings"),
//                .copy("Resources/models.json"),
            ]
        ),
        .executableTarget(
            name: "mcp-server",
            dependencies: [
                .product(name: "MCP", package: "mcp-swift-sdk"),
                .product(name: "Ontology", package: "Ontology"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            path: "Sources/CLI"
        ),
    ]
)
