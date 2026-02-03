# API Reference

Complete API documentation for the Qdrant Swift client.

## Table of Contents

- [Client Initialization](#client-initialization)
- [Collections Service](#collections-service)
- [Points Service](#points-service)
- [Snapshots Service](#snapshots-service)
- [Service Operations (REST only)](#service-operations-rest-only)
- [Data Types](#data-types)

## Client Initialization

### gRPC Client

```swift
import QdrantGRPC

// Basic initialization
let client = try await QdrantGRPCClient(host: "localhost", port: 6334)

// With all options
let client = try await QdrantGRPCClient(
    host: "your-cluster.cloud.qdrant.io",
    port: 6334,
    apiKey: "your-api-key",
    useTLS: true
)

// Always close when done
defer { client.close() }

// Health check
let health = try await client.healthCheck()
// Returns: HealthCheckResult(title: String, version: String)
```

### REST Client

```swift
import QdrantREST

let client = try QdrantRESTClient(
    host: "localhost",
    port: 6333,
    useTLS: false,
    apiKey: nil
)

// Health check
let health = try await client.healthCheck()
```

---

## Collections Service

Access via `client.collections`.

### list()

List all collections.

```swift
let collections = try await client.collections.list()
// Returns: [CollectionDescription]
```

### exists(name:)

Check if a collection exists.

```swift
let exists = try await client.collections.exists(name: "my_collection")
// Returns: Bool
```

### get(name:)

Get collection info.

```swift
let info = try await client.collections.get(name: "my_collection")
// Returns: CollectionInfo
// Properties: name, status (.green, .yellow, .red, .grey)
```

### create(name:vectorSize:distance:onDiskPayload:)

Create a simple collection.

```swift
try await client.collections.create(
    name: "vectors",
    vectorSize: 384,
    distance: .cosine,        // .cosine, .euclid, .dot, .manhattan
    onDiskPayload: nil        // Optional: store payload on disk
)
```

### create(name:vectors:onDiskPayload:)

Create a multi-vector collection.

```swift
try await client.collections.create(
    name: "multi_vector",
    vectors: [
        "text": VectorConfig(size: 384, distance: .cosine),
        "image": VectorConfig(size: 512, distance: .euclid)
    ],
    onDiskPayload: nil
)
```

### update(name:...)

Update collection parameters.

```swift
// gRPC
try await client.collections.update(
    name: "vectors",
    indexingThreshold: 10000
)

// REST
try await client.collections.update(
    name: "vectors",
    optimizersConfig: RestOptimizersConfigDiff(indexingThreshold: 10000)
)
```

### delete(name:)

Delete a collection.

```swift
try await client.collections.delete(name: "my_collection")
```

### Aliases

```swift
// Create alias
try await client.collections.createAlias(alias: "production", collection: "vectors_v2")

// Delete alias
try await client.collections.deleteAlias(alias: "old_alias")

// List aliases for a collection
let aliases = try await client.collections.listAliases(collection: "vectors")
// Returns: [AliasDescription]

// List all aliases
let allAliases = try await client.collections.listAllAliases()
```

### Shard Management

```swift
// Get cluster info
let clusterInfo = try await client.collections.collectionClusterInfo(name: "vectors")

// Create shard key
try await client.collections.createShardKey(
    collection: "vectors",
    shardKey: .keyword("tenant_a"),
    shardsNumber: 2
)

// Delete shard key
try await client.collections.deleteShardKey(
    collection: "vectors",
    shardKey: .keyword("tenant_a")
)
```

---

## Points Service

Access via `client.points`.

### upsert(collection:points:wait:)

Insert or update points.

```swift
try await client.points.upsert(
    collection: "vectors",
    points: [
        Point(id: .integer(1), vector: [0.1, 0.2, ...], payload: ["key": .string("value")]),
        Point(id: .uuid("..."), vector: embedding, payload: nil)
    ],
    wait: true  // Wait for indexing to complete
)
```

### get(collection:ids:withPayload:withVectors:)

Retrieve points by ID.

```swift
let points = try await client.points.get(
    collection: "vectors",
    ids: [.integer(1), .integer(2)],
    withPayload: true,
    withVectors: true
)
// Returns: [RetrievedPoint]
```

### delete(collection:ids:wait:)

Delete points by ID.

```swift
try await client.points.delete(
    collection: "vectors",
    ids: [.integer(1), .integer(2)],
    wait: true
)
```

### delete(collection:filter:wait:)

Delete points matching a filter.

```swift
try await client.points.delete(
    collection: "vectors",
    filter: Filter(must: [.field(FieldCondition(key: "status", match: .keyword("deleted")))]),
    wait: true
)
```

### scroll(collection:filter:limit:offset:withPayload:withVectors:)

Iterate through points.

```swift
let result = try await client.points.scroll(
    collection: "vectors",
    filter: nil,
    limit: 100,
    offset: nil,  // Use result.nextPageOffset for pagination
    withPayload: true,
    withVectors: false
)
// Returns: ScrollResult(points: [RetrievedPoint], nextPageOffset: PointID?)
```

### count(collection:filter:exact:)

Count points.

```swift
let count = try await client.points.count(
    collection: "vectors",
    filter: nil,
    exact: true
)
// Returns: UInt64
```

### search(collection:vector:limit:filter:scoreThreshold:offset:withPayload:withVectors:vectorName:)

Search for similar vectors.

```swift
let results = try await client.points.search(
    collection: "vectors",
    vector: queryEmbedding,
    limit: 10,
    filter: nil,
    scoreThreshold: nil,  // Minimum score
    offset: nil,
    withPayload: true,
    withVectors: false,
    vectorName: nil  // For multi-vector collections
)
// Returns: [ScoredPoint]
```

### searchBatch(collection:searches:)

Multiple searches in one request.

```swift
let results = try await client.points.searchBatch(
    collection: "vectors",
    searches: [
        SearchRequest(vector: query1, limit: 5, withPayload: true),
        SearchRequest(vector: query2, limit: 5, filter: myFilter)
    ]
)
// Returns: [[ScoredPoint]]
```

### searchGroups(collection:vector:groupBy:limit:groupSize:...)

Search with grouping.

```swift
let groups = try await client.points.searchGroups(
    collection: "vectors",
    vector: queryEmbedding,
    groupBy: "category",
    limit: 5,        // Number of groups
    groupSize: 3,    // Results per group
    withPayload: true
)
// Returns: [PointGroup]
```

### query(collection:query:...)

Flexible query interface.

```swift
// Query by vector
let results = try await client.points.query(
    collection: "vectors",
    query: .nearest([0.1, 0.2, ...]),
    limit: 10,
    withPayload: true
)

// Query by point ID
let results = try await client.points.query(
    collection: "vectors",
    query: .recommend(positive: [.integer(1)], negative: []),
    limit: 10
)
```

### queryBatch(collection:queries:)

Multiple queries in one request.

```swift
let results = try await client.points.queryBatch(
    collection: "vectors",
    queries: [
        QueryRequest(query: .nearest(embedding1), limit: 5),
        QueryRequest(query: .nearest(embedding2), limit: 5)
    ]
)
```

### queryGroups(collection:query:groupBy:...)

Query with grouping.

```swift
let groups = try await client.points.queryGroups(
    collection: "vectors",
    query: .nearest(queryEmbedding),
    groupBy: "category",
    limit: 5,
    groupSize: 3
)
```

### recommend(collection:positive:negative:limit:...)

Get recommendations based on existing points.

```swift
let results = try await client.points.recommend(
    collection: "vectors",
    positive: [.integer(1), .integer(2)],
    negative: [.integer(3)],
    limit: 10,
    filter: nil,
    scoreThreshold: nil,
    withPayload: true,
    withVectors: false
)
// Returns: [ScoredPoint]
```

### recommendBatch(collection:requests:)

Batch recommendations.

```swift
let results = try await client.points.recommendBatch(
    collection: "vectors",
    requests: [
        RecommendRequest(positive: [.integer(1)], limit: 5),
        RecommendRequest(positive: [.integer(2)], negative: [.integer(3)], limit: 5)
    ]
)
```

### recommendGroups(collection:positive:groupBy:...)

Recommendations with grouping.

```swift
let groups = try await client.points.recommendGroups(
    collection: "vectors",
    positive: [.integer(1)],
    groupBy: "category",
    limit: 5,
    groupSize: 3
)
```

### discover(collection:target:context:limit:...)

Context-based discovery.

```swift
let results = try await client.points.discover(
    collection: "vectors",
    target: .vector([0.1, 0.2, ...]),
    context: [
        ContextPair(positive: .vector(pos), negative: .vector(neg))
    ],
    limit: 10,
    withPayload: true
)
```

### discoverBatch(collection:requests:)

Batch discovery.

```swift
let results = try await client.points.discoverBatch(
    collection: "vectors",
    requests: [
        DiscoverRequest(target: .vector(t1), context: ctx1, limit: 5),
        DiscoverRequest(target: .vector(t2), context: ctx2, limit: 5)
    ]
)
```

### facet(collection:key:limit:filter:exact:)

Get facet counts.

```swift
let result = try await client.points.facet(
    collection: "vectors",
    key: "category",
    limit: 10,
    filter: nil,
    exact: true
)
// Returns: FacetResult with hits containing value and count
```

### searchMatrixPairs(collection:sample:limit:filter:)

Get similarity matrix as pairs.

```swift
let result = try await client.points.searchMatrixPairs(
    collection: "vectors",
    sample: 100,
    limit: 10
)
// Returns: SearchMatrixPairsResult with pairs
```

### searchMatrixOffsets(collection:sample:limit:filter:)

Get similarity matrix as offsets.

```swift
let result = try await client.points.searchMatrixOffsets(
    collection: "vectors",
    sample: 100,
    limit: 10
)
// Returns: SearchMatrixOffsetsResult with ids and offsets
```

### Payload Operations

```swift
// Set payload (merge)
try await client.points.setPayload(
    collection: "vectors",
    ids: [.integer(1)],
    payload: ["key": .string("value")],
    wait: true
)

// Overwrite payload (replace)
try await client.points.overwritePayload(
    collection: "vectors",
    ids: [.integer(1)],
    payload: ["only": .string("this")],
    wait: true
)

// Delete payload keys
try await client.points.deletePayload(
    collection: "vectors",
    ids: [.integer(1)],
    keys: ["unwanted"],
    wait: true
)

// Clear all payload
try await client.points.clearPayload(
    collection: "vectors",
    ids: [.integer(1)],
    wait: true
)
```

### Vector Operations

```swift
// Update vectors
try await client.points.updateVectors(
    collection: "vectors",
    points: [
        (id: .integer(1), vector: .dense(newEmbedding))
    ],
    wait: true
)

// Delete named vectors
try await client.points.deleteVectors(
    collection: "multi_vector",
    ids: [.integer(1)],
    vectorNames: ["image"],  // Delete only "image" vector
    wait: true
)
```

### Field Indexes

```swift
// Create index
try await client.points.createFieldIndex(
    collection: "vectors",
    fieldName: "category",
    fieldType: .keyword,  // .keyword, .integer, .float, .bool, .geo, .text
    wait: true
)

// Delete index
try await client.points.deleteFieldIndex(
    collection: "vectors",
    fieldName: "category",
    wait: true
)
```

### Batch Update

```swift
let result = try await client.points.updateBatch(
    collection: "vectors",
    operations: [
        .upsert(points),
        .deletePoints(ids),
        .setPayload(ids: ids, payload: payload),
        .overwritePayload(ids: ids, payload: payload),
        .deletePayload(ids: ids, keys: keys),
        .clearPayload(ids: ids),
        .updateVectors(points: vectorUpdates),
        .deleteVectors(ids: ids, vectors: vectorNames)
    ],
    wait: true
)
// Returns: BatchUpdateResult with statuses
```

---

## Snapshots Service

Access via `client.snapshots`.

### Collection Snapshots

```swift
// Create snapshot
let snapshot = try await client.snapshots.create(collection: "vectors")
// Returns: SnapshotDescription(name: String, size: Int64)

// List snapshots
let snapshots = try await client.snapshots.list(collection: "vectors")
// Returns: [SnapshotDescription]

// Delete snapshot
try await client.snapshots.delete(collection: "vectors", snapshot: "snapshot_name")
```

### Full Storage Snapshots

```swift
// Create full snapshot
let snapshot = try await client.snapshots.createFull()

// List full snapshots
let snapshots = try await client.snapshots.listFull()

// Delete full snapshot
try await client.snapshots.deleteFull(snapshot: "snapshot_name")
```

---

## Service Operations (REST only)

These methods are only available on `QdrantRESTClient`.

```swift
// Telemetry data
let telemetry = try await client.telemetry()

// Prometheus metrics
let metrics = try await client.metrics()
// Returns: String (Prometheus format)

// List issues
let issues = try await client.issues()
// Returns: [QdrantIssue]

// Clear issues
try await client.clearIssues()
```

---

## Data Types

### PointID

```swift
// Integer ID
let id: PointID = .integer(42)
let id: PointID = 42  // Literal

// UUID string
let id: PointID = .uuid("550e8400-e29b-41d4-a716-446655440000")
let id: PointID = "my-uuid"  // Literal
```

### VectorData

```swift
// Dense vector
let vector: VectorData = .dense([0.1, 0.2, 0.3])
let vector: VectorData = [0.1, 0.2, 0.3]  // Literal

// Named vectors
let vector: VectorData = .named([
    "text": [0.1, 0.2, 0.3],
    "image": [0.4, 0.5, 0.6]
])
```

### PayloadValue

```swift
let payload: [String: PayloadValue] = [
    "string": .string("hello"),
    "integer": .integer(42),
    "double": .double(3.14),
    "bool": .bool(true),
    "array": .array([.string("a"), .string("b")]),
    "object": .object(["nested": .string("value")])
]

// Literals work too
let payload: [String: PayloadValue] = [
    "title": "Hello",  // String literal
    "count": 42,       // Integer literal
    "score": 0.95,     // Double literal
    "active": true     // Bool literal
]

// Access values
if let title = payload["title"]?.stringValue { ... }
if let count = payload["count"]?.integerValue { ... }
```

### Distance

```swift
enum Distance {
    case cosine     // Cosine similarity (normalized)
    case euclid     // Euclidean distance
    case dot        // Dot product
    case manhattan  // Manhattan distance
}
```

### Filter

```swift
let filter = Filter(
    must: [Condition],      // All must match (AND)
    should: [Condition],    // At least one must match (OR)
    mustNot: [Condition]    // None must match (NOT)
)
```

### Condition

```swift
// Field condition
.field(FieldCondition(key: "category", match: .keyword("tech")))
.field(FieldCondition(key: "price", range: Range(gte: 10, lte: 100)))

// Check if field exists
.isEmpty(key: "optional_field")
.isNull(key: "nullable_field")

// Match by IDs
.hasId(ids: [.integer(1), .integer(2)])

// Nested filter
.filter(nestedFilter)
```

### Match

```swift
.keyword("exact_value")           // Exact string match
.keywords(["a", "b", "c"])        // Match any
.except("not_this")               // Exclude value
.exceptKeywords(["x", "y"])       // Exclude any
.text("full text search")         // Full-text search
```

### Range

```swift
Range(gt: 10)                     // Greater than
Range(gte: 10)                    // Greater than or equal
Range(lt: 100)                    // Less than
Range(lte: 100)                   // Less than or equal
Range(gte: 10, lte: 100)          // Between
Range.between(10, 100)            // Convenience method
```
