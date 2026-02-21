# Qdrant Swift Client

A native Swift client library for [Qdrant](https://qdrant.tech/) vector database. Supports both gRPC and REST protocols.

## Features

- **Dual Protocol Support**: gRPC (high performance) and REST (lightweight)
- **Qdrant Cloud Ready**: Works with Qdrant Cloud out of the box
- **Swift 6 Concurrency**: Full async/await support
- **Minimal Dependencies**: REST client has zero external dependencies
- **Type-Safe API**: Strong typing with Swift literals for payloads

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/hansdoebel/qdrant-swift.git", from: "1.0.0")
]
```

Choose your client:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "QdrantGRPC", package: "qdrant-swift"),  // gRPC client
        // or
        .product(name: "QdrantREST", package: "qdrant-swift"),  // REST client
    ]
)
```

## Quick Start

### gRPC Client

```swift
import QdrantGRPC

// Connect to local Qdrant
let client = try await QdrantGRPCClient(host: "localhost", port: 6334)
defer { client.close() }

// Create a collection
try await client.collections.create(
    name: "my_vectors",
    vectorSize: 384,
    distance: .cosine
)

// Insert vectors
try await client.points.upsert(
    collection: "my_vectors",
    points: [
        Point(
            id: .integer(1),
            vector: embedding,
            payload: ["title": .string("Document 1")]
        )
    ]
)

// Search
let results = try await client.points.search(
    collection: "my_vectors",
    vector: queryEmbedding,
    limit: 10,
    withPayload: true
)
```

### REST Client

```swift
import QdrantREST

let client = try QdrantRESTClient(host: "localhost", port: 6333)

// Same API as gRPC client
try await client.collections.create(name: "my_vectors", vectorSize: 384, distance: .cosine)
```

### Qdrant Cloud

```swift
let client = try await QdrantGRPCClient(
    host: "your-cluster.aws.cloud.qdrant.io",
    port: 6334,
    apiKey: "your-api-key"
)
// TLS is automatically enabled for non-localhost hosts
```

## gRPC vs REST

| Feature | gRPC | REST |
|---------|------|------|
| Performance | Higher throughput | Standard HTTP |
| Dependencies | grpc-swift, SwiftNIO | None |
| Port | 6334 | 6333 |
| Best For | Production | Prototyping |

Both clients have identical APIs. Use gRPC for production, REST for simplicity.

## Security

- **TLS Auto-Detection**: TLS is automatically enabled for non-localhost connections
- **TLS Enforcement**: Explicitly disabling TLS for remote hosts throws an error
- **API Key Security**: API keys are transmitted via secure headers, never logged

## Requirements

- Swift 6.0+
- macOS 15+ / iOS 18+
- Qdrant 1.x

## Running Qdrant

```bash
docker run -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

## Project Structure

```
qdrant-swift/
├── Sources/
│   ├── QdrantCore/          # Shared models and protocols (used by both clients)
│   │   ├── Models/          # Point, Filter, Distance, PayloadValue, etc.
│   │   └── Protocols/       # Service protocols for dependency injection
│   ├── QdrantGRPC/          # gRPC client implementation
│   │   ├── Configuration/   # Client configuration
│   │   ├── Errors/          # gRPC-specific errors
│   │   ├── ProtoExtensions/ # Swift extensions for proto type conversion
│   │   ├── Protos/          # Raw .proto definition files
│   │   └── Services/        # Collection, Points, Snapshots services
│   ├── QdrantProto/         # Auto-generated Swift code from .proto files
│   └── QdrantREST/          # REST client implementation
│       ├── Client/          # HTTP client wrapper
│       ├── Errors/          # REST-specific errors (RESTError)
│       ├── Models/          # REST-specific response models
│       └── Services/        # Collection, Points, Snapshots services
├── Tests/
│   ├── IntegrationTests/    # End-to-end tests (requires Qdrant server)
│   ├── Mocks/               # Mock implementations for unit testing
│   └── Qdrant*Tests/        # Unit tests for each module
├── Docs/                    # Documentation
└── Package.swift            # Swift Package Manager manifest
```

## Development

Check for outdated dependencies:

```bash
make update-deps
```

## Documentation

- [Usage Examples](Docs/USAGE.md) - Detailed examples and common patterns
- [API Reference](Docs/API.md) - Complete API documentation
- [Testing Guide](Docs/TESTING.md) - How to run and write tests

## Resources

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Qdrant Cloud](https://cloud.qdrant.io/)

## License

MIT License - see [LICENSE](LICENSE) for details.
