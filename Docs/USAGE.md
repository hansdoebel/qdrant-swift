# Usage Examples

This guide covers common usage patterns for the Qdrant Swift client.

## Table of Contents

- [Connecting to Qdrant](#connecting-to-qdrant)
- [Working with Collections](#working-with-collections)
- [Inserting Vectors](#inserting-vectors)
- [Searching](#searching)
- [Query API](#query-api)
- [Filtering](#filtering)
- [Recommendations](#recommendations)
- [Discovery](#discovery)
- [Scroll and Pagination](#scroll-and-pagination)
- [Payload Operations](#payload-operations)
- [Vector Operations](#vector-operations)
- [Snapshots](#snapshots)
- [Faceted Search](#faceted-search)
- [Error Handling](#error-handling)
- [Complete Examples](#complete-examples)

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
    apiKey: "your-api-key"
)
defer { client.close() }

// TLS is automatically enabled for non-localhost hosts
// Health check
let health = try await client.healthCheck()
print("Connected to Qdrant \(health.version)")
```

### Connection with Custom Configuration

```swift
// gRPC with explicit TLS
let client = try await QdrantGRPCClient(
    host: "qdrant.mycompany.com",
    port: 6334,
    apiKey: ProcessInfo.processInfo.environment["QDRANT_API_KEY"],
    useTLS: true
)

// REST with custom URLSession
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 30
let session = URLSession(configuration: config)

let restClient = try QdrantRESTClient(
    host: "localhost",
    port: 6333,
    session: session
)
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

// With on-disk payload storage (for large payloads)
try await client.collections.create(
    name: "large_docs",
    vectorSize: 768,
    distance: .cosine,
    onDiskPayload: true
)
```

### Check and Delete

```swift
// Check if exists
let exists = try await client.collections.exists(name: "documents")

// Get info
let info = try await client.collections.get(name: "documents")
print("Status: \(info.status)")
print("Points count: \(info.pointsCount)")
print("Vectors count: \(info.vectorsCount)")

// List all collections
let collections = try await client.collections.list()
for collection in collections {
    print("Collection: \(collection.name)")
}

// Delete
try await client.collections.delete(name: "documents")
```

### Collection Aliases

Aliases allow zero-downtime collection swaps:

```swift
// Create alias pointing to v1
try await client.collections.createAlias(alias: "production", collection: "documents_v1")

// Later, swap to v2 atomically (gRPC only)
try await client.collections.renameAlias(oldAlias: "production", newAlias: "production_old")
try await client.collections.createAlias(alias: "production", collection: "documents_v2")
try await client.collections.deleteAlias(alias: "production_old")

// List aliases for a specific collection
let aliases = try await client.collections.listAliases(collection: "documents_v1")

// List all aliases
let allAliases = try await client.collections.listAllAliases()
for alias in allAliases {
    print("\(alias.aliasName) -> \(alias.collectionName)")
}
```

### Update Collection Settings

```swift
// gRPC client
try await client.collections.update(
    name: "documents",
    indexingThreshold: 20000,  // Trigger indexing after 20k vectors
    onDiskPayload: true
)

// REST client
try await restClient.collections.update(
    name: "documents",
    optimizersConfig: RestOptimizersConfigDiff(indexingThreshold: 20000),
    params: RestCollectionParamsDiff(onDiskPayload: true)
)
```

## Inserting Vectors

### Basic Upsert

```swift
let points = [
    Point(
        id: .integer(1),
        vector: [0.1, 0.2, 0.3, /* ... 384 dimensions */],
        payload: [
            "title": .string("Introduction to Swift"),
            "category": .string("programming"),
            "year": .integer(2024),
            "rating": .double(4.5),
            "published": .bool(true)
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
    wait: true  // Wait for indexing to complete
)
```

### Using Swift Literals for Payload

```swift
// PayloadValue supports ExpressibleBy*Literal protocols
let point = Point(
    id: 1,  // Integer literal for PointID
    vector: [0.1, 0.2, 0.3],
    payload: [
        "title": "My Document",     // String literal
        "count": 42,                // Integer literal
        "score": 0.95,              // Float literal
        "active": true,             // Bool literal
        "tags": .array([.string("swift"), .string("ios")]),
        "metadata": .object([
            "author": .string("John"),
            "version": .integer(2)
        ])
    ]
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
// Multiple operations in one request - more efficient than separate calls
let results = try await client.points.updateBatch(
    collection: "documents",
    operations: [
        .upsert(points: newPoints),
        .deletePoints(ids: [.integer(5), .integer(6)]),
        .setPayload(ids: [.integer(1)], payload: ["updated": .bool(true)]),
        .deletePayload(ids: [.integer(2)], keys: ["temporary"]),
        .clearPayload(ids: [.integer(3)])
    ],
    wait: true
)

// Check results
for result in results {
    print("Operation status: \(result.status)")
}
```

### Delete Points

```swift
// Delete by IDs
try await client.points.delete(
    collection: "documents",
    ids: [.integer(1), .integer(2), .uuid("abc-123")],
    wait: true
)

// Delete by filter
let filter = Filter(must: [
    .field(FieldCondition(key: "status", match: .keyword("archived")))
])
try await client.points.delete(
    collection: "documents",
    filter: filter,
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
    scoreThreshold: 0.8  // Only return matches with score >= 0.8
)
```

### Search with Offset (Pagination)

```swift
// Page 1
let page1 = try await client.points.search(
    collection: "documents",
    vector: queryEmbedding,
    limit: 10,
    offset: 0
)

// Page 2
let page2 = try await client.points.search(
    collection: "documents",
    vector: queryEmbedding,
    limit: 10,
    offset: 10
)
```

### Search in Named Vector

```swift
let results = try await client.points.search(
    collection: "multi_modal",
    vector: textQuery,
    limit: 10,
    vectorName: "text"  // Search only in the "text" vector space
)
```

### Batch Search

```swift
// Execute multiple searches in parallel
let batchResults = try await client.points.searchBatch(
    collection: "documents",
    searches: [
        SearchBatchQuery(vector: query1, limit: 5, withPayload: true),
        SearchBatchQuery(vector: query2, limit: 5, withPayload: true, filter: someFilter),
        SearchBatchQuery(vector: query3, limit: 10, scoreThreshold: 0.9)
    ]
)

// batchResults[0] contains results for query1
// batchResults[1] contains results for query2
// batchResults[2] contains results for query3
```

### Grouped Search

Group results by a payload field (e.g., one result per category):

```swift
let groups = try await client.points.searchGroups(
    collection: "documents",
    vector: queryEmbedding,
    groupBy: "category",
    limit: 5,       // Number of groups
    groupSize: 2,   // Results per group
    withPayload: true
)

for group in groups.groups {
    print("Category: \(group.id)")
    for hit in group.hits {
        print("  - Score: \(hit.score), Title: \(hit.payload?["title"]?.stringValue ?? "")")
    }
}
```

## Query API

The Query API provides a flexible, unified interface for various search operations.

### Basic Query

```swift
// Query with a vector
let results = try await client.points.query(
    collection: "documents",
    query: .nearest(queryEmbedding),
    limit: 10,
    withPayload: true
)
```

### Query with Prefetch (Two-Stage Search)

```swift
// First stage: broad search, second stage: re-rank
let results = try await client.points.query(
    collection: "documents",
    prefetch: [
        RestPrefetchQuery(
            query: .nearest(queryEmbedding),
            limit: 100  // Get top 100 candidates
        )
    ],
    query: .nearest(rerankEmbedding),  // Re-rank with different embedding
    limit: 10,
    withPayload: true
)
```

### Batch Query

```swift
let batchResults = try await client.points.queryBatch(
    collection: "documents",
    queries: [
        QueryBatchQuery(query: .nearest(embedding1), limit: 5),
        QueryBatchQuery(query: .nearest(embedding2), limit: 5, filter: myFilter)
    ]
)
```

### Query Groups

```swift
let groups = try await client.points.queryGroups(
    collection: "documents",
    query: .nearest(queryEmbedding),
    groupBy: "author",
    limit: 5,
    groupSize: 3,
    withPayload: true
)
```

## Filtering

### Basic Filters

```swift
// Exact match
let filter = Filter(must: [
    .field(FieldCondition(key: "category", match: .keyword("programming")))
])

// Multiple values (match any)
let filter = Filter(must: [
    .field(FieldCondition(key: "tag", match: .keywords(["swift", "ios", "macos"])))
])

// Exclude values
let filter = Filter(must: [
    .field(FieldCondition(key: "status", match: .exceptKeywords(["draft", "archived"])))
])

// Range filter
let filter = Filter(must: [
    .field(FieldCondition(key: "year", range: Range(gte: 2020, lte: 2024)))
])

// Greater than only
let filter = Filter(must: [
    .field(FieldCondition(key: "price", range: Range(gt: 100)))
])
```

### Combining Conditions

```swift
let filter = Filter(
    must: [
        // All must match (AND)
        .field(FieldCondition(key: "published", match: .keyword("true")))
    ],
    should: [
        // At least one should match (OR)
        .field(FieldCondition(key: "category", match: .keyword("swift"))),
        .field(FieldCondition(key: "category", match: .keyword("ios")))
    ],
    mustNot: [
        // None should match (NOT)
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

### Nested Filters

```swift
let filter = Filter(
    must: [
        .field(FieldCondition(key: "active", match: .keyword("true"))),
        .filter(Filter(
            should: [
                .field(FieldCondition(key: "tier", match: .keyword("premium"))),
                .field(FieldCondition(key: "credits", range: Range(gte: 100)))
            ]
        ))
    ]
)
```

### Special Conditions

```swift
// Check if field exists (is not null and not empty)
let filter = Filter(must: [
    .isEmpty(key: "optional_field", isEmpty: false)
])

// Check if field is null
let filter = Filter(must: [
    .isNull(key: "deleted_at", isNull: true)
])

// Filter by point IDs
let filter = Filter(must: [
    .hasId(ids: [.integer(1), .integer(2), .integer(3)])
])
```

### Full-Text Search

```swift
// Requires a text index on the field
try await client.points.createFieldIndex(
    collection: "documents",
    fieldName: "content",
    fieldType: .text
)

// Full-text search in filter
let filter = Filter(must: [
    .field(FieldCondition(key: "content", match: .text("swift programming tutorial")))
])

let results = try await client.points.search(
    collection: "documents",
    vector: queryEmbedding,
    limit: 10,
    filter: filter
)
```

### Creating Indexes for Faster Filtering

```swift
// Keyword index (for exact matches)
try await client.points.createFieldIndex(
    collection: "documents",
    fieldName: "category",
    fieldType: .keyword
)

// Integer index (for ranges)
try await client.points.createFieldIndex(
    collection: "documents",
    fieldName: "year",
    fieldType: .integer
)

// Float index
try await client.points.createFieldIndex(
    collection: "documents",
    fieldName: "price",
    fieldType: .float
)

// Bool index
try await client.points.createFieldIndex(
    collection: "documents",
    fieldName: "published",
    fieldType: .bool
)

// Text index (for full-text search)
try await client.points.createFieldIndex(
    collection: "documents",
    fieldName: "content",
    fieldType: .text
)

// Delete an index
try await client.points.deleteFieldIndex(
    collection: "documents",
    fieldName: "old_field"
)
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

// Find similar to multiple points
let results = try await client.points.recommend(
    collection: "documents",
    positive: [.integer(1), .integer(2), .integer(3)],
    limit: 10
)

// Find similar to some, but not others
let results = try await client.points.recommend(
    collection: "documents",
    positive: [.integer(1), .integer(2)],  // Similar to these
    negative: [.integer(3), .integer(4)],   // Not like these
    limit: 10,
    filter: categoryFilter  // Additional filtering
)
```

### Batch Recommendations

```swift
let batchResults = try await client.points.recommendBatch(
    collection: "documents",
    recommends: [
        RecommendBatchQuery(positive: [.integer(1)], limit: 5),
        RecommendBatchQuery(positive: [.integer(2)], negative: [.integer(3)], limit: 5)
    ]
)
```

### Grouped Recommendations

```swift
let groups = try await client.points.recommendGroups(
    collection: "documents",
    positive: [.integer(1)],
    groupBy: "category",
    limit: 5,
    groupSize: 3,
    withPayload: true
)
```

## Discovery

Discovery uses context pairs to guide the search - find points that are similar to positive examples relative to negative examples.

```swift
// Basic discovery
let results = try await client.points.discover(
    collection: "documents",
    target: .id(.integer(1)),  // Find points similar to this
    context: [
        RestContextPair(
            positive: .id(.integer(2)),   // Should be similar to this
            negative: .id(.integer(3))    // Should be different from this
        )
    ],
    limit: 10,
    withPayload: true
)

// Discovery with vector target
let results = try await client.points.discover(
    collection: "documents",
    target: .vector(queryEmbedding),
    context: [
        RestContextPair(
            positive: .vector(positiveExample),
            negative: .vector(negativeExample)
        )
    ],
    limit: 10
)
```

### Batch Discovery

```swift
let batchResults = try await client.points.discoverBatch(
    collection: "documents",
    discovers: [
        DiscoverBatchQuery(
            target: .id(.integer(1)),
            context: [RestContextPair(positive: .id(.integer(2)), negative: .id(.integer(3)))],
            limit: 5
        ),
        DiscoverBatchQuery(
            target: .id(.integer(4)),
            context: [RestContextPair(positive: .id(.integer(5)), negative: .id(.integer(6)))],
            limit: 5
        )
    ]
)
```

## Scroll and Pagination

Scroll through all points in a collection (for export, backup, or processing):

```swift
// First page
var result = try await client.points.scroll(
    collection: "documents",
    limit: 100,
    withPayload: true,
    withVectors: false
)

var allPoints = result.points

// Continue scrolling while there are more pages
while let nextOffset = result.nextPageOffset {
    result = try await client.points.scroll(
        collection: "documents",
        limit: 100,
        offset: nextOffset,
        withPayload: true,
        withVectors: false
    )
    allPoints.append(contentsOf: result.points)
}

print("Total points: \(allPoints.count)")
```

### Scroll with Filter

```swift
let filter = Filter(must: [
    .field(FieldCondition(key: "category", match: .keyword("programming")))
])

let result = try await client.points.scroll(
    collection: "documents",
    filter: filter,
    limit: 100,
    withPayload: true
)
```

### Get Points by ID

```swift
let points = try await client.points.get(
    collection: "documents",
    ids: [.integer(1), .integer(2), .uuid("abc-123")],
    withPayload: true,
    withVectors: true
)

for point in points {
    print("ID: \(point.id)")
    if let vector = point.vector {
        print("Vector dimensions: \(vector.count)")
    }
}
```

### Count Points

```swift
// Count all points
let totalCount = try await client.points.count(
    collection: "documents",
    exact: true
)
print("Total points: \(totalCount)")

// Count with filter
let filter = Filter(must: [
    .field(FieldCondition(key: "status", match: .keyword("active")))
])
let activeCount = try await client.points.count(
    collection: "documents",
    filter: filter,
    exact: true
)
print("Active points: \(activeCount)")
```

## Payload Operations

### Set Payload (Merge)

```swift
// Add or update specific fields (other fields remain unchanged)
try await client.points.setPayload(
    collection: "documents",
    ids: [.integer(1), .integer(2)],
    payload: [
        "status": .string("reviewed"),
        "score": .double(0.95),
        "reviewedAt": .string(ISO8601DateFormatter().string(from: Date()))
    ]
)
```

### Overwrite Payload (Replace)

```swift
// Replace entire payload (removes fields not specified)
try await client.points.overwritePayload(
    collection: "documents",
    ids: [.integer(1)],
    payload: [
        "title": .string("New Title"),
        "content": .string("New content only")
    ]
)
```

### Delete Payload Fields

```swift
// Remove specific fields
try await client.points.deletePayload(
    collection: "documents",
    ids: [.integer(1), .integer(2)],
    keys: ["temporary_field", "debug_info"]
)
```

### Clear All Payload

```swift
// Remove all payload data (keep vectors)
try await client.points.clearPayload(
    collection: "documents",
    ids: [.integer(1)]
)
```

## Vector Operations

### Update Vectors

```swift
// Update vectors for existing points
try await client.points.updateVectors(
    collection: "documents",
    points: [
        PointVectorUpdate(id: .integer(1), vector: newEmbedding1),
        PointVectorUpdate(id: .integer(2), vector: newEmbedding2)
    ]
)

// Update named vectors
try await client.points.updateVectors(
    collection: "multi_modal",
    points: [
        PointVectorUpdate(id: .integer(1), vector: .named(["text": newTextEmbedding]))
    ]
)
```

### Delete Vectors

```swift
// Delete specific named vectors (keep other vectors and payload)
try await client.points.deleteVectors(
    collection: "multi_modal",
    ids: [.integer(1), .integer(2)],
    vectors: ["image"]  // Only delete the "image" vector
)
```

## Snapshots

### Collection Snapshots

```swift
// Create a snapshot
let snapshot = try await client.snapshots.create(collection: "documents")
print("Created snapshot: \(snapshot.name)")
print("Size: \(snapshot.size) bytes")

// List all snapshots
let snapshots = try await client.snapshots.list(collection: "documents")
for snap in snapshots {
    print("Snapshot: \(snap.name), Created: \(snap.creationTime ?? Date())")
}

// Delete a snapshot
try await client.snapshots.delete(collection: "documents", snapshot: snapshot.name)
```

### Full Storage Snapshots

```swift
// Create a full snapshot (all collections)
let fullSnapshot = try await client.snapshots.createFull()
print("Full snapshot: \(fullSnapshot.name)")

// List full snapshots
let fullSnapshots = try await client.snapshots.listFull()

// Delete a full snapshot
try await client.snapshots.deleteFull(snapshot: fullSnapshot.name)
```

## Faceted Search

Get aggregated counts for payload field values:

```swift
// Get facet counts for a field
let facetResult = try await client.points.facet(
    collection: "documents",
    key: "category",
    limit: 10,
    exact: true
)

for hit in facetResult.hits {
    print("Category: \(hit.value), Count: \(hit.count)")
}

// Facet with filter
let filter = Filter(must: [
    .field(FieldCondition(key: "year", range: Range(gte: 2023)))
])

let filteredFacets = try await client.points.facet(
    collection: "documents",
    key: "category",
    limit: 10,
    filter: filter
)
```

## Error Handling

### Handling Common Errors

```swift
import QdrantGRPC

do {
    let info = try await client.collections.get(name: "nonexistent")
} catch let error as QdrantError {
    switch error {
    case .collectionNotFound(let name):
        print("Collection '\(name)' does not exist")
    case .unauthenticated:
        print("Invalid API key")
    case .permissionDenied:
        print("Access denied")
    case .connectionFailed(let message):
        print("Connection failed: \(message)")
    case .timeout:
        print("Request timed out")
    default:
        print("Qdrant error: \(error.localizedDescription)")
    }
}
```

### REST Client Errors

```swift
import QdrantREST

do {
    let info = try await restClient.collections.get(name: "nonexistent")
} catch let error as RESTError {
    switch error {
    case .collectionNotFound(let name):
        print("Collection '\(name)' does not exist")
    case .statusCode(let code, let message):
        print("HTTP \(code): \(message ?? "Unknown error")")
    case .networkError(let underlying):
        print("Network error: \(underlying.localizedDescription)")
    case .decodingFailed(let underlying):
        print("Failed to decode response: \(underlying)")
    case .tlsRequiredForRemoteHost(let host):
        print("TLS required for \(host)")
    default:
        print("REST error: \(error.localizedDescription)")
    }
}
```

### Retry Logic

```swift
func searchWithRetry(
    collection: String,
    vector: [Float],
    maxRetries: Int = 3
) async throws -> [ScoredPoint] {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            return try await client.points.search(
                collection: collection,
                vector: vector,
                limit: 10
            )
        } catch let error as QdrantError {
            lastError = error
            
            // Don't retry client errors
            if case .collectionNotFound = error { throw error }
            if case .unauthenticated = error { throw error }
            
            // Retry on transient errors
            if attempt < maxRetries {
                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }
    
    throw lastError!
}
```

## Complete Examples

### Semantic Search App

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

            // Create indexes for filtering
            try await client!.points.createFieldIndex(
                collection: collectionName,
                fieldName: "category",
                fieldType: .keyword
            )
            try await client!.points.createFieldIndex(
                collection: collectionName,
                fieldName: "created_at",
                fieldType: .integer
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
                "created_at": .integer(Int64(Date().timeIntervalSince1970))
            ]
        )

        try await client?.points.upsert(
            collection: collectionName,
            points: [point],
            wait: true
        )
    }

    func search(
        embedding: [Float],
        category: String? = nil,
        limit: Int = 10
    ) async throws -> [SearchResult] {
        var filter: Filter? = nil
        if let category {
            filter = Filter(must: [
                .field(FieldCondition(key: "category", match: .keyword(category)))
            ])
        }

        let results = try await client?.points.search(
            collection: collectionName,
            vector: embedding,
            limit: limit,
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

### RAG (Retrieval-Augmented Generation) Helper

```swift
import QdrantGRPC

actor RAGStore {
    private let client: QdrantGRPCClient
    private let collectionName: String
    
    init(client: QdrantGRPCClient, collection: String) {
        self.client = client
        self.collectionName = collection
    }
    
    /// Add documents with their embeddings
    func addDocuments(_ documents: [(id: String, text: String, embedding: [Float], metadata: [String: String])]) async throws {
        let points = documents.map { doc in
            var payload: [String: PayloadValue] = [
                "text": .string(doc.text)
            ]
            for (key, value) in doc.metadata {
                payload[key] = .string(value)
            }
            
            return Point(
                id: .uuid(doc.id),
                vector: doc.embedding,
                payload: payload
            )
        }
        
        try await client.points.upsert(
            collection: collectionName,
            points: points,
            wait: true
        )
    }
    
    /// Retrieve relevant context for a query
    func retrieveContext(
        queryEmbedding: [Float],
        topK: Int = 5,
        scoreThreshold: Float = 0.7
    ) async throws -> [String] {
        let results = try await client.points.search(
            collection: collectionName,
            vector: queryEmbedding,
            limit: topK,
            scoreThreshold: scoreThreshold,
            withPayload: true
        )
        
        return results.compactMap { $0.payload?["text"]?.stringValue }
    }
    
    /// Retrieve with metadata filtering
    func retrieveContext(
        queryEmbedding: [Float],
        source: String,
        topK: Int = 5
    ) async throws -> [String] {
        let filter = Filter(must: [
            .field(FieldCondition(key: "source", match: .keyword(source)))
        ])
        
        let results = try await client.points.search(
            collection: collectionName,
            vector: queryEmbedding,
            limit: topK,
            filter: filter,
            withPayload: true
        )
        
        return results.compactMap { $0.payload?["text"]?.stringValue }
    }
}
```

### Multi-Tenant Application

```swift
import QdrantGRPC

actor MultiTenantVectorDB {
    private let client: QdrantGRPCClient
    private let collectionName: String
    
    init(client: QdrantGRPCClient, collection: String) async throws {
        self.client = client
        self.collectionName = collection
        
        // Ensure collection exists with tenant index
        let exists = try await client.collections.exists(name: collection)
        if !exists {
            try await client.collections.create(
                name: collection,
                vectorSize: 384,
                distance: .cosine
            )
            
            // Index for tenant filtering
            try await client.points.createFieldIndex(
                collection: collection,
                fieldName: "tenant_id",
                fieldType: .keyword
            )
        }
    }
    
    /// Add vectors for a specific tenant
    func upsert(tenantId: String, points: [Point]) async throws {
        // Add tenant_id to all points
        let tenantPoints = points.map { point in
            var payload = point.payload ?? [:]
            payload["tenant_id"] = .string(tenantId)
            return Point(id: point.id, vector: point.vector, payload: payload)
        }
        
        try await client.points.upsert(
            collection: collectionName,
            points: tenantPoints,
            wait: true
        )
    }
    
    /// Search within a tenant's data only
    func search(
        tenantId: String,
        vector: [Float],
        limit: Int = 10,
        additionalFilter: Filter? = nil
    ) async throws -> [ScoredPoint] {
        var conditions: [Condition] = [
            .field(FieldCondition(key: "tenant_id", match: .keyword(tenantId)))
        ]
        
        // Merge with additional filter if provided
        if let additional = additionalFilter {
            conditions.append(.filter(additional))
        }
        
        let filter = Filter(must: conditions)
        
        return try await client.points.search(
            collection: collectionName,
            vector: vector,
            limit: limit,
            filter: filter,
            withPayload: true
        )
    }
    
    /// Delete all data for a tenant
    func deleteTenant(tenantId: String) async throws {
        let filter = Filter(must: [
            .field(FieldCondition(key: "tenant_id", match: .keyword(tenantId)))
        ])
        
        try await client.points.delete(
            collection: collectionName,
            filter: filter,
            wait: true
        )
    }
}
```

### Image Similarity Search

```swift
import QdrantGRPC

struct ImageSearchService {
    let client: QdrantGRPCClient
    let collectionName = "images"
    
    func setup() async throws {
        let exists = try await client.collections.exists(name: collectionName)
        if !exists {
            try await client.collections.create(
                name: collectionName,
                vectorSize: 512,  // CLIP embedding size
                distance: .cosine
            )
            
            // Indexes for filtering
            try await client.points.createFieldIndex(
                collection: collectionName,
                fieldName: "album",
                fieldType: .keyword
            )
            try await client.points.createFieldIndex(
                collection: collectionName,
                fieldName: "date",
                fieldType: .integer
            )
        }
    }
    
    func addImage(
        id: String,
        embedding: [Float],
        url: String,
        album: String,
        date: Date,
        tags: [String]
    ) async throws {
        let point = Point(
            id: .uuid(id),
            vector: embedding,
            payload: [
                "url": .string(url),
                "album": .string(album),
                "date": .integer(Int64(date.timeIntervalSince1970)),
                "tags": .array(tags.map { .string($0) })
            ]
        )
        
        try await client.points.upsert(
            collection: collectionName,
            points: [point],
            wait: true
        )
    }
    
    func findSimilarImages(
        embedding: [Float],
        album: String? = nil,
        dateRange: (start: Date, end: Date)? = nil,
        limit: Int = 20
    ) async throws -> [(url: String, score: Float)] {
        var conditions: [Condition] = []
        
        if let album {
            conditions.append(.field(FieldCondition(key: "album", match: .keyword(album))))
        }
        
        if let dateRange {
            conditions.append(.field(FieldCondition(
                key: "date",
                range: Range(
                    gte: Int64(dateRange.start.timeIntervalSince1970),
                    lte: Int64(dateRange.end.timeIntervalSince1970)
                )
            )))
        }
        
        let filter = conditions.isEmpty ? nil : Filter(must: conditions)
        
        let results = try await client.points.search(
            collection: collectionName,
            vector: embedding,
            limit: limit,
            filter: filter,
            withPayload: true
        )
        
        return results.compactMap { point in
            guard let url = point.payload?["url"]?.stringValue else { return nil }
            return (url: url, score: point.score)
        }
    }
    
    func findDuplicates(embedding: [Float], threshold: Float = 0.98) async throws -> [String] {
        let results = try await client.points.search(
            collection: collectionName,
            vector: embedding,
            limit: 10,
            scoreThreshold: threshold,
            withPayload: true
        )
        
        return results.compactMap { $0.payload?["url"]?.stringValue }
    }
}
```

## Next Steps

- See [API Reference](API.md) for complete method documentation
- See [Testing Guide](TESTING.md) for running tests
