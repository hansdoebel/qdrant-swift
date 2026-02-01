# Testing Guide

This guide explains how to run tests and use mocks for the Qdrant Swift client.

## Table of Contents

- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Unit Tests](#unit-tests)
- [Integration Tests](#integration-tests)
- [Using Mocks](#using-mocks)

## Test Structure

```
Tests/
├── QdrantCoreTests/       # Core model tests (no server needed)
├── QdrantGRPCTests/       # gRPC client unit tests
├── QdrantRESTTests/       # REST client unit tests
├── IntegrationTests/      # End-to-end tests (requires Qdrant)
└── Mocks/                 # Mock implementations for testing
```

## Running Tests

### All Tests

```bash
swift test
```

### Specific Test Suites

```bash
# Unit tests only (no server required)
swift test --filter QdrantCoreTests
swift test --filter QdrantGRPCTests
swift test --filter QdrantRESTTests

# Integration tests (requires running Qdrant)
swift test --filter IntegrationTests

# Specific integration tests
swift test --filter GRPCIntegrationTests
swift test --filter RestIntegrationTests

# Quick cloud validation (5 essential tests)
swift test --filter CloudValidationTests
```

### Single Test

```bash
swift test --filter "GRPCIntegrationTests/healthCheck"
```

## Unit Tests

Unit tests verify models and serialization without a Qdrant server.

### QdrantCoreTests

Tests core data types:
- `PointID` (integer, UUID, literals, Codable)
- `PayloadValue` (all types, literals, Codable)
- `Filter` and conditions
- `VectorData` (dense, named)
- `Distance` enum

### QdrantGRPCTests / QdrantRESTTests

Tests client-specific types and configuration:
- Configuration defaults
- TLS auto-detection
- Type serialization

## Integration Tests

Integration tests verify actual API operations against a running Qdrant instance.

### Prerequisites

You need a running Qdrant instance. Options:

#### Option 1: Local Docker (Recommended)

```bash
# Start Qdrant
docker compose -f docker-compose.test.yml up -d

# Create .env file
cp env.local.example .env

# Run tests
swift test --filter IntegrationTests

# Stop when done
docker compose -f docker-compose.test.yml down
```

Contents of `docker-compose.test.yml`:

```yaml
version: '3.8'
services:
  qdrant:
    image: qdrant/qdrant:latest
    ports:
      - "6333:6333"
      - "6334:6334"
```

Contents of `.env` for local Docker:

```
QDRANT_URL=http://localhost:6333
```

#### Option 2: Qdrant Cloud

```bash
export QDRANT_URL=https://your-cluster.cloud.qdrant.io
export QDRANT_API_KEY=your-api-key
export QDRANT_TEST_COLLECTION=test-collection

swift test --filter IntegrationTests
```

Or create a `.env` file:

```
QDRANT_URL=https://your-cluster.cloud.qdrant.io
QDRANT_API_KEY=your-api-key
QDRANT_TEST_COLLECTION=test-collection
```

### Cloud Validation Tests

For quick validation against Qdrant Cloud, use `CloudValidationTests`. This minimal test suite validates core SDK functionality in about 1 second:

```bash
swift test --filter CloudValidationTests
```

**What it tests:**
1. **Connectivity** - Verifies connection and API key authentication
2. **Collection lifecycle** - Create, exists, get info, delete
3. **Points upsert & get** - Insert and retrieve points with payloads
4. **Vector search** - Similarity search with results verification
5. **Payload operations** - Set and retrieve payload data

This is ideal for:
- Verifying your Qdrant Cloud setup works
- Quick smoke tests before deployment
- CI/CD pipelines where full tests are too slow

### What Integration Tests Cover

Both gRPC and REST tests cover:

- **Health**: Health check endpoint
- **Collections**: Create, delete, list, exists, get, update, aliases
- **Points**: Upsert, get, delete, scroll, count
- **Search**: Basic search, batch, groups, with filters
- **Query**: Basic query, batch, groups
- **Recommend**: Basic, batch, groups
- **Discover**: Basic, batch
- **Facets**: Faceted search
- **Matrix**: Search matrix pairs/offsets
- **Payload**: Set, overwrite, delete, clear
- **Vectors**: Update, delete
- **Indexes**: Create, delete field indexes
- **Snapshots**: Create, list, delete

## Using Mocks

The `Tests/Mocks` directory provides mock implementations for unit testing your application code.

### Available Mocks

- `MockCollectionsService` - Mock for collections operations
- `MockPointsService` - Mock for points operations
- `MockSnapshotsService` - Mock for snapshot operations

### Example Usage

```swift
import XCTest
@testable import YourApp
@testable import QdrantCore

class MyServiceTests: XCTestCase {
    var mockCollections: MockCollectionsService!
    var mockPoints: MockPointsService!
    
    override func setUp() {
        mockCollections = MockCollectionsService()
        mockPoints = MockPointsService()
    }
    
    func testCreateCollectionIfNotExists() async throws {
        // Configure mock
        mockCollections.existsResult = .success(false)
        mockCollections.createResult = .success(())
        
        // Test your service
        let service = MyVectorService(collections: mockCollections)
        try await service.ensureCollectionExists("test")
        
        // Verify calls
        XCTAssertEqual(mockCollections.existsCallCount, 1)
        XCTAssertEqual(mockCollections.existsCalls, ["test"])
        XCTAssertEqual(mockCollections.createCallCount, 1)
    }
    
    func testSearchWithResults() async throws {
        // Configure mock to return results
        mockPoints.searchResult = .success([
            ScoredPoint(
                id: .integer(1),
                score: 0.95,
                payload: ["title": .string("Test")],
                vector: nil
            )
        ])
        
        let service = MySearchService(points: mockPoints)
        let results = try await service.search(query: "test")
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(mockPoints.searchCallCount, 1)
    }
    
    func testHandlesError() async throws {
        // Configure mock to throw error
        mockCollections.getResult = .failure(QdrantError.collectionNotFound("missing"))
        
        let service = MyVectorService(collections: mockCollections)
        
        do {
            try await service.getCollectionInfo("missing")
            XCTFail("Expected error")
        } catch {
            // Expected
        }
    }
}
```

### Mock Properties

Each mock tracks calls and allows configuring results:

```swift
let mock = MockCollectionsService()

// Configure return values
mock.listResult = .success([CollectionDescription(name: "test")])
mock.existsResult = .success(true)
mock.createResult = .failure(SomeError())

// After calling methods, check:
mock.listCallCount          // Number of times list() was called
mock.existsCallCount        // Number of times exists() was called
mock.existsCalls            // Array of collection names passed to exists()
mock.createCalls            // Array of create parameters

// Reset between tests
mock.reset()
```

### Testing Filters

```swift
func testSearchWithFilter() async throws {
    mockPoints.searchResult = .success([...])
    
    let filter = Filter(must: [
        .field(FieldCondition(key: "category", match: .keyword("tech")))
    ])
    
    try await mockPoints.search(
        collection: "test",
        vector: [0.1, 0.2, 0.3],
        limit: 10,
        filter: filter
    )
    
    // Verify filter was passed
    XCTAssertEqual(mockPoints.searchCalls.count, 1)
    XCTAssertNotNil(mockPoints.searchCalls[0].filter)
}
```

## Writing New Tests

### Unit Test Template

```swift
import Testing
@testable import QdrantCore

@Suite("My Feature Tests")
struct MyFeatureTests {
    
    @Test("Description of what this tests")
    func myTest() throws {
        // Arrange
        let input = ...
        
        // Act
        let result = ...
        
        // Assert
        #expect(result == expected)
    }
    
    @Test("Async operation")
    func asyncTest() async throws {
        let result = try await someAsyncOperation()
        #expect(result != nil)
    }
}
```

### Integration Test Template

```swift
import Testing
@testable import QdrantGRPC

@Suite("My Integration Tests", .serialized)
struct MyIntegrationTests {
    
    private func createClient() async throws -> QdrantGRPCClient {
        let config = try IntegrationTestConfig.load()
        // ... create and return client
    }
    
    @Test("End-to-end operation")
    func e2eTest() async throws {
        let client = try await createClient()
        defer { client.close() }
        
        let collectionName = "test-\(UUID().uuidString.prefix(8))"
        
        // Create
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )
        
        // Test operations...
        
        // Cleanup
        try await client.collections.delete(name: collectionName)
    }
}
```

## CI/CD Integration

For CI environments, set environment variables:

```yaml
# GitHub Actions example
env:
  QDRANT_URL: http://localhost:6333

services:
  qdrant:
    image: qdrant/qdrant:latest
    ports:
      - 6333:6333
      - 6334:6334

steps:
  - uses: actions/checkout@v4
  - name: Run tests
    run: swift test
```
