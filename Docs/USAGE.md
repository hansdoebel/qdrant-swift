# Usage Examples

This guide covers common usage patterns for the Qdrant Swift client.

## Table of Contents

- [Connecting to Qdrant](#connecting-to-qdrant)
- [Working with Collections](#working-with-collections)
- [Inserting Vectors](#inserting-vectors)
- [Searching](#searching)
- [Filtering](#filtering)
- [Recommendations](#recommendations)
- [Payload Operations](#payload-operations)
- [Complete Example: Semantic Search App](#complete-example-semantic-search-app)

## Connecting to Qdrant

### Local Instance

```swift
import QdrantGRPC

// gRPC client (port 6334)
let client = try await QdrantGRPCClient(host: "localhost", port: 6334)
defer { client.close() }

// REST client (port 6333)
import QdrantREST
let restClient = try QdrantRESTClient(host: "localhost", port: 6333)
```

### Qdrant Cloud

```swift
let client = try await QdrantGRPCClient(
    host: "your-cluster-id.region.aws.cloud.qdrant.io",
    port: 6334,
    apiKey: "your-api-key",
    useTLS: true
)
defer { client.close() }

// Health check
let health = try await client.healthCheck()
print("Connected to Qdrant \(health.version)")
```

## Working with Collections

### Create a Collection

```swift
// Simple collection with single vector
try await client.collections.create(
    name: "documents",
    vectorSize: 384,
    distance: .cosine
)

// Multi-vector collection
try await client.collections.create(
    name: "multi_modal",
    vectors: [
        "text": VectorConfig(size: 384, distance: .cosine),
        "image": VectorConfig(size: 512, distance: .euclid)
    ]
)
```

### Check and Delete

```swift
// Check if exists
let exists = try await client.collections.exists(name: "documents")

// Get info
let info = try await client.collections.get(name: "documents")
print("Status: \(info.status)")

// Delete
try await client.collections.delete(name: "documents")
```

### Collection Aliases

Aliases allow zero-downtime collection swaps:

```swift
// Create alias pointing to v1
try await client.collections.createAlias(alias: "production", collection: "documents_v1")

// Later, swap to v2
try await client.collections.deleteAlias(alias: "production")
try await client.collections.createAlias(alias: "production", collection: "documents_v2")

// List aliases
let aliases = try await client.collections.listAllAliases()
```

## Inserting Vectors

### Basic Upsert

```swift
let points = [
    Point(
        id: .integer(1),
        vector: [0.1, 0.2, 0.3, /* ... */],
        payload: [
            "title": .string("Introduction to Swift"),
            "category": .string("programming"),
            "year": .integer(2024)
        ]
    ),
    Point(
        id: .uuid("550e8400-e29b-41d4-a716-446655440000"),
        vector: embedding2,
        payload: ["title": .string("Advanced Patterns")]
    )
]

try await client.points.upsert(
    collection: "documents",
    points: points,
    wait: true  // Wait for indexing
)
```

### Multi-Vector Points

```swift
let point = Point(
    id: .integer(1),
    vector: .named([
        "text": textEmbedding,
        "image": imageEmbedding
    ]),
    payload: ["description": .string("A photo of a cat")]
)

try await client.points.upsert(collection: "multi_modal", points: [point])
```

### Batch Operations

```swift
// Multiple operations in one request
try await client.points.updateBatch(
    collection: "documents",
    operations: [
        .upsert(points: newPoints),
        .deletePoints(ids: [.integer(5), .integer(6)]),
        .setPayload(ids: [.integer(1)], payload: ["updated": .bool(true)])
    ],
    wait: true
)
```

## Searching

### Basic Search

```swift
let results = try await client.points.search(
    collection: "documents",
    vector: queryEmbedding,
    limit: 10,
    withPayload: true,
    withVectors: false
)

for result in results {
    print("ID: \(result.id), Score: \(result.score)")
    if let title = result.payload?["title"]?.stringValue {
        print("Title: \(title)")
    }
}
```

### Search with Score Threshold

```swift
let results = try await client.points.search(
    collection: "documents",
    vector: queryEmbedding,
    limit: 10,
    scoreThreshold: 0.8  // Only high-confidence matches
)
```

### Search in Named Vector

```swift
let results = try await client.points.search(
    collection: "multi_modal",
    vector: textQuery,
    limit: 10,
    vectorName: "text"
)
```

### Batch Search

```swift
let batchResults = try await client.points.searchBatch(
    collection: "documents",
    searches: [
        SearchRequest(vector: query1, limit: 5, withPayload: true),
        SearchRequest(vector: query2, limit: 5, withPayload: true)
    ]
)

// batchResults[0] contains results for query1
// batchResults[1] contains results for query2
```

### Grouped Search

Group results by a field (e.g., one result per category):

```swift
let groups = try await client.points.searchGroups(
    collection: "documents",
    vector: queryEmbedding,
    groupBy: "category",
    limit: 5,       // Number of groups
    groupSize: 2,   // Results per group
    withPayload: true
)

for group in groups {
    print("Group: \(group.id)")
    for hit in group.hits {
        print("  - \(hit.payload?["title"]?.stringValue ?? "")")
    }
}
```

## Filtering

### Basic Filters

```swift
// Exact match
let filter = Filter(must: [
    .field(FieldCondition(key: "category", match: .keyword("programming")))
])

// Multiple values (OR)
let filter = Filter(must: [
    .field(FieldCondition(key: "tag", match: .keywords(["swift", "ios", "macos"])))
])

// Range
let filter = Filter(must: [
    .field(FieldCondition(key: "year", range: Range(gte: 2020, lte: 2024)))
])
```

### Combining Conditions

```swift
let filter = Filter(
    must: [
        .field(FieldCondition(key: "published", match: .keyword("true")))
    ],
    should: [
        .field(FieldCondition(key: "category", match: .keyword("swift"))),
        .field(FieldCondition(key: "category", match: .keyword("ios")))
    ],
    mustNot: [
        .field(FieldCondition(key: "archived", match: .keyword("true")))
    ]
)

let results = try await client.points.search(
    collection: "documents",
    vector: queryEmbedding,
    limit: 10,
    filter: filter
)
```

### Creating Indexes for Faster Filtering

```swift
// Create index on frequently filtered fields
try await client.points.createFieldIndex(
    collection: "documents",
    fieldName: "category",
    fieldType: .keyword,
    wait: true
)

// Available types: .keyword, .integer, .float, .bool, .geo, .text
```

## Recommendations

Find similar items based on existing points:

```swift
// Find items similar to point 1
let results = try await client.points.recommend(
    collection: "documents",
    positive: [.integer(1)],
    limit: 10,
    withPayload: true
)

// Find similar to some, but not others
let results = try await client.points.recommend(
    collection: "documents",
    positive: [.integer(1), .integer(2)],  // Similar to these
    negative: [.integer(3)],                // Not like this
    limit: 10
)
```

## Payload Operations

### Update Payload

```swift
// Add/update fields (merge)
try await client.points.setPayload(
    collection: "documents",
    ids: [.integer(1), .integer(2)],
    payload: ["status": .string("reviewed"), "score": .double(0.95)]
)

// Replace entire payload
try await client.points.overwritePayload(
    collection: "documents",
    ids: [.integer(1)],
    payload: ["only_this": .string("field")]
)

// Delete specific fields
try await client.points.deletePayload(
    collection: "documents",
    ids: [.integer(1)],
    keys: ["temporary_field"]
)

// Clear all payload
try await client.points.clearPayload(
    collection: "documents",
    ids: [.integer(1)]
)
```

## Complete Example: Semantic Search App

```swift
import SwiftUI
import QdrantGRPC

@MainActor
class VectorStore: ObservableObject {
    private var client: QdrantGRPCClient?
    private let collectionName = "documents"

    func connect() async throws {
        client = try await QdrantGRPCClient(host: "localhost", port: 6334)

        // Create collection if needed
        let exists = try await client!.collections.exists(name: collectionName)
        if !exists {
            try await client!.collections.create(
                name: collectionName,
                vectorSize: 384,
                distance: .cosine
            )

            // Create index for filtering
            try await client!.points.createFieldIndex(
                collection: collectionName,
                fieldName: "category",
                fieldType: .keyword
            )
        }
    }

    func addDocument(id: Int, text: String, embedding: [Float], category: String) async throws {
        let point = Point(
            id: .integer(UInt64(id)),
            vector: embedding,
            payload: [
                "text": .string(text),
                "category": .string(category),
                "indexed_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
        )

        try await client?.points.upsert(
            collection: collectionName,
            points: [point],
            wait: true
        )
    }

    func search(embedding: [Float], category: String? = nil, limit: Int = 10) async throws -> [SearchResult] {
        var filter: Filter? = nil
        if let category {
            filter = Filter(must: [
                .field(FieldCondition(key: "category", match: .keyword(category)))
            ])
        }

        let results = try await client?.points.search(
            collection: collectionName,
            vector: embedding,
            limit: UInt64(limit),
            filter: filter,
            withPayload: true
        ) ?? []

        return results.map { point in
            SearchResult(
                id: point.id,
                score: point.score,
                text: point.payload?["text"]?.stringValue ?? "",
                category: point.payload?["category"]?.stringValue ?? ""
            )
        }
    }

    func disconnect() {
        client?.close()
        client = nil
    }
}

struct SearchResult: Identifiable {
    let id: PointID
    let score: Float
    let text: String
    let category: String
}
```

## Next Steps

- See [API Reference](API.md) for complete method documentation
- See [Testing Guide](TESTING.md) for running tests
