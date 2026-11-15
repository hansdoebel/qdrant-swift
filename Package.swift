// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "qdrant-swift",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
    ],
    products: [
        .library(
            name: "QdrantCore",
            targets: ["QdrantCore"]
        ),
        .library(
            name: "QdrantGRPC",
            targets: ["QdrantGRPC"]
        ),
        .library(
            name: "QdrantREST",
            targets: ["QdrantREST"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.4"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.41.0"),
    ],
    targets: [
        .target(
            name: "QdrantCore",
            dependencies: [],
            path: "Sources/QdrantCore"
        ),
        .target(
            name: "QdrantProto",
            dependencies: [
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Sources/QdrantProto"
        ),
        .target(
            name: "QdrantGRPC",
            dependencies: [
                "QdrantCore",
                "QdrantProto",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
            ],
            path: "Sources/QdrantGRPC",
            exclude: ["Protos"]
        ),
        .target(
            name: "QdrantREST",
            dependencies: [
                "QdrantCore"
            ],
            path: "Sources/QdrantRest"
        ),
        .target(
            name: "QdrantMocks",
            dependencies: ["QdrantCore"],
            path: "Tests/Mocks"
        ),
        .testTarget(
            name: "QdrantCoreTests",
            dependencies: ["QdrantCore"],
            path: "Tests/QdrantCoreTests"
        ),
        .testTarget(
            name: "QdrantGRPCTests",
            dependencies: ["QdrantGRPC", "QdrantProto", "QdrantMocks"],
            path: "Tests/QdrantGRPCTests"
        ),
        .testTarget(
            name: "QdrantRESTTests",
            dependencies: ["QdrantREST", "QdrantMocks"],
            path: "Tests/QdrantRestTests"
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["QdrantGRPC", "QdrantREST", "QdrantCore"],
            path: "Tests/IntegrationTests"
        ),
    ]
)
