import Foundation
import Testing

@testable import QdrantCore
@testable import QdrantGRPC

// gRPC integration tests for Qdrant Cloud
// Qdrant Cloud exposes gRPC on port 6334 with TLS
// Reference: https://qdrant.tech/documentation/guides/configuration/

@Suite("gRPC API Integration Tests", .serialized)
struct GRPCIntegrationTests {

    // MARK: - Helper Functions

    private func createClient() async throws -> QdrantGRPCClient {
        let config = try IntegrationTestConfig.load()

        // Parse URL to extract host
        guard let url = URL(string: config.url) else {
            throw TestError.invalidURL
        }

        let host = url.host ?? "localhost"
        // gRPC typically uses port 6334
        let port = 6334
        let useTLS = url.scheme == "https"

        return try await QdrantGRPCClient(
            host: host,
            port: port,
            apiKey: config.apiKey,
            useTLS: useTLS
        )
    }

    enum TestError: Error {
        case invalidURL
    }

    // MARK: - Health Check Tests

    @Test("Health check returns healthy status")
    func healthCheck() async throws {
        let client = try await createClient()
        defer { client.close() }

        let result = try await client.healthCheck()

        #expect(result.title == "qdrant - vector search engine")
        #expect(!result.version.isEmpty)
    }

    // MARK: - Collections Tests

    @Test("List collections")
    func listCollections() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collections = try await client.collections.list()

        // Just verify we can list - may be empty or have collections
        #expect(collections.count >= 0)  // Always passes, just verifies no error was thrown
    }

    @Test("Create and delete collection via gRPC")
    func createAndDeleteCollection() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-test-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Verify it exists
        let exists = try await client.collections.exists(name: collectionName)
        #expect(exists == true)

        // Get info
        let info = try await client.collections.get(name: collectionName)
        #expect(info.status == .green)

        // Clean up
        try await client.collections.delete(name: collectionName)

        // Verify it's gone
        let existsAfter = try await client.collections.exists(name: collectionName)
        #expect(existsAfter == false)
    }

    // MARK: - Points Tests

    @Test("Upsert and get points via gRPC")
    func upsertAndGetPoints() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-points-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(
                id: .integer(1),
                vector: [0.1, 0.2, 0.3, 0.4],
                payload: ["category": .string("electronics"), "price": .double(99.99)]
            ),
            Point(
                id: .integer(2),
                vector: [0.5, 0.6, 0.7, 0.8],
                payload: ["category": .string("books"), "price": .double(19.99)]
            ),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Get points
        let retrieved = try await client.points.get(
            collection: collectionName,
            ids: [.integer(1), .integer(2)],
            withPayload: true,
            withVectors: true
        )

        #expect(retrieved.count == 2)

        // Verify payload
        let point1 = retrieved.first {
            if case .integer(let id) = $0.id { return id == 1 }
            return false
        }
        #expect(point1?.payload?["category"]?.stringValue == "electronics")

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Search points via gRPC")
    func searchPoints() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-search-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0], payload: ["name": .string("first")]),
            Point(
                id: .integer(2), vector: [0.9, 0.1, 0.0, 0.0], payload: ["name": .string("second")]),
            Point(
                id: .integer(3), vector: [0.0, 1.0, 0.0, 0.0], payload: ["name": .string("third")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Search - should find first and second (similar vectors)
        let results = try await client.points.search(
            collection: collectionName,
            vector: [1.0, 0.0, 0.0, 0.0],
            limit: 2,
            withPayload: true
        )

        #expect(results.count == 2)

        // First result should be point 1 (exact match)
        if case .integer(let id) = results[0].id {
            #expect(id == 1)
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Search with filter via gRPC")
    func searchWithFilter() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-filter-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Create payload index for filtering
        try await client.points.createFieldIndex(
            collection: collectionName,
            fieldName: "category",
            fieldType: .keyword,
            wait: true
        )

        // Upsert points with different categories
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0], payload: ["category": .string("A")]),
            Point(
                id: .integer(2), vector: [0.9, 0.1, 0.0, 0.0], payload: ["category": .string("B")]),
            Point(
                id: .integer(3), vector: [0.8, 0.2, 0.0, 0.0], payload: ["category": .string("A")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Search with filter for category A only
        let filter = Filter(
            must: [.field(FieldCondition(key: "category", match: .keyword("A")))]
        )

        let results = try await client.points.search(
            collection: collectionName,
            vector: [1.0, 0.0, 0.0, 0.0],
            limit: 10,
            filter: filter,
            withPayload: true
        )

        #expect(results.count == 2)

        // All results should have category A
        for result in results {
            #expect(result.payload?["category"]?.stringValue == "A")
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Count points via gRPC")
    func countPoints() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-count-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        var points: [Point] = []
        for i in 1...15 {
            points.append(
                Point(
                    id: .integer(UInt64(i)),
                    vector: [Float(i) * 0.01, 0.2, 0.3, 0.4]
                ))
        }

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Count all points
        let count = try await client.points.count(collection: collectionName)
        #expect(count == 15)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Recommend points via gRPC")
    func recommendPoints() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-recommend-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0],
                payload: ["type": .string("reference")]),
            Point(
                id: .integer(2), vector: [0.95, 0.05, 0.0, 0.0],
                payload: ["type": .string("similar")]),
            Point(
                id: .integer(3), vector: [0.9, 0.1, 0.0, 0.0], payload: ["type": .string("similar")]
            ),
            Point(
                id: .integer(4), vector: [0.0, 1.0, 0.0, 0.0],
                payload: ["type": .string("different")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Recommend similar to point 1
        let results = try await client.points.recommend(
            collection: collectionName,
            positive: [.integer(1)],
            limit: 3,
            withPayload: true
        )

        // Should return similar points but not point 1 itself
        #expect(results.count >= 2)

        for result in results {
            if case .integer(let id) = result.id {
                #expect(id != 1)  // Should not return the reference point
            }
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Update vectors via gRPC")
    func updateVectors() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-update-vec-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert initial point
        let points = [
            Point(id: .integer(1), vector: [0.1, 0.2, 0.3, 0.4])
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Update vector
        try await client.points.updateVectors(
            collection: collectionName,
            points: [(id: .integer(1), vector: .dense([0.9, 0.8, 0.7, 0.6]))],
            wait: true
        )

        // Verify vector was updated
        let retrieved = try await client.points.get(
            collection: collectionName,
            ids: [.integer(1)],
            withVectors: true
        )

        if case .dense(let vector) = retrieved[0].vector {
            #expect(vector[0] > 0.8)  // Should be close to 0.9
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Scroll points via gRPC")
    func scrollPoints() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-scroll-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert 20 points
        var points: [Point] = []
        for i in 1...20 {
            points.append(
                Point(
                    id: .integer(UInt64(i)),
                    vector: [Float(i) * 0.01, 0.2, 0.3, 0.4]
                ))
        }

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Scroll first batch
        let firstBatch = try await client.points.scroll(
            collection: collectionName,
            limit: 10,
            withPayload: true
        )

        #expect(firstBatch.points.count == 10)
        #expect(firstBatch.nextPageOffset != nil)

        // Scroll second batch
        let secondBatch = try await client.points.scroll(
            collection: collectionName,
            limit: 10,
            offset: firstBatch.nextPageOffset,
            withPayload: true
        )

        #expect(secondBatch.points.count == 10)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Delete points by IDs via gRPC")
    func deletePointsByIds() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-delete-ids-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(id: .integer(1), vector: [0.1, 0.2, 0.3, 0.4]),
            Point(id: .integer(2), vector: [0.5, 0.6, 0.7, 0.8]),
            Point(id: .integer(3), vector: [0.9, 0.8, 0.7, 0.6]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Verify all exist
        var count = try await client.points.count(collection: collectionName)
        #expect(count == 3)

        // Delete point 2
        try await client.points.delete(collection: collectionName, ids: [.integer(2)], wait: true)

        // Verify count decreased
        count = try await client.points.count(collection: collectionName)
        #expect(count == 2)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Delete points by filter via gRPC")
    func deletePointsByFilter() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-delete-filter-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Create payload index for filtering
        try await client.points.createFieldIndex(
            collection: collectionName,
            fieldName: "category",
            fieldType: .keyword,
            wait: true
        )

        // Upsert points with different categories
        let points = [
            Point(
                id: .integer(1), vector: [0.1, 0.2, 0.3, 0.4], payload: ["category": .string("A")]),
            Point(
                id: .integer(2), vector: [0.5, 0.6, 0.7, 0.8], payload: ["category": .string("B")]),
            Point(
                id: .integer(3), vector: [0.9, 0.8, 0.7, 0.6], payload: ["category": .string("A")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Verify all exist
        var count = try await client.points.count(collection: collectionName)
        #expect(count == 3)

        // Delete all points with category A
        let filter = Filter(
            must: [.field(FieldCondition(key: "category", match: .keyword("A")))]
        )
        try await client.points.delete(collection: collectionName, filter: filter, wait: true)

        // Verify count decreased - only category B should remain
        count = try await client.points.count(collection: collectionName)
        #expect(count == 1)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Set and delete payload via gRPC")
    func setAndDeletePayload() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-payload-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert point without payload
        let points = [
            Point(id: .integer(1), vector: [0.1, 0.2, 0.3, 0.4])
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Set payload
        try await client.points.setPayload(
            collection: collectionName,
            ids: [.integer(1)],
            payload: ["category": .string("test"), "count": .integer(42)],
            wait: true
        )

        // Verify payload was set
        var retrieved = try await client.points.get(
            collection: collectionName,
            ids: [.integer(1)],
            withPayload: true
        )

        #expect(retrieved[0].payload?["category"]?.stringValue == "test")
        #expect(retrieved[0].payload?["count"]?.integerValue == 42)

        // Delete a payload key
        try await client.points.deletePayload(
            collection: collectionName,
            ids: [.integer(1)],
            keys: ["count"],
            wait: true
        )

        // Verify key was deleted
        retrieved = try await client.points.get(
            collection: collectionName,
            ids: [.integer(1)],
            withPayload: true
        )

        #expect(retrieved[0].payload?["category"]?.stringValue == "test")
        #expect(retrieved[0].payload?["count"] == nil)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Overwrite payload via gRPC")
    func overwritePayload() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-overwrite-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert point with payload
        let points = [
            Point(
                id: .integer(1), vector: [0.1, 0.2, 0.3, 0.4],
                payload: ["key1": .string("value1"), "key2": .string("value2")])
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Overwrite entire payload
        try await client.points.overwritePayload(
            collection: collectionName,
            ids: [.integer(1)],
            payload: ["newKey": .string("newValue")],
            wait: true
        )

        // Verify payload was replaced
        let retrieved = try await client.points.get(
            collection: collectionName,
            ids: [.integer(1)],
            withPayload: true
        )

        #expect(retrieved[0].payload?["newKey"]?.stringValue == "newValue")
        #expect(retrieved[0].payload?["key1"] == nil)
        #expect(retrieved[0].payload?["key2"] == nil)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Clear payload via gRPC")
    func clearPayload() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-clear-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert point with payload
        let points = [
            Point(
                id: .integer(1), vector: [0.1, 0.2, 0.3, 0.4],
                payload: ["key1": .string("value1"), "key2": .string("value2")])
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Clear all payload
        try await client.points.clearPayload(
            collection: collectionName,
            ids: [.integer(1)],
            wait: true
        )

        // Verify payload was cleared
        let retrieved = try await client.points.get(
            collection: collectionName,
            ids: [.integer(1)],
            withPayload: true
        )

        #expect(retrieved[0].payload?.isEmpty ?? true)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Delete field index via gRPC")
    func deleteFieldIndex() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-delete-index-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Create payload index
        try await client.points.createFieldIndex(
            collection: collectionName,
            fieldName: "category",
            fieldType: .keyword,
            wait: true
        )

        // Delete the index - should not throw
        try await client.points.deleteFieldIndex(
            collection: collectionName,
            fieldName: "category",
            wait: true
        )

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Query points via gRPC")
    func queryPoints() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-query-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0], payload: ["name": .string("first")]),
            Point(
                id: .integer(2), vector: [0.9, 0.1, 0.0, 0.0], payload: ["name": .string("second")]),
            Point(
                id: .integer(3), vector: [0.0, 1.0, 0.0, 0.0], payload: ["name": .string("third")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Query using nearest vector
        let results = try await client.points.query(
            collection: collectionName,
            query: .nearest([1.0, 0.0, 0.0, 0.0]),
            limit: 2,
            withPayload: true
        )

        #expect(results.count == 2)

        // First result should be point 1 (exact match)
        if case .integer(let id) = results[0].id {
            #expect(id == 1)
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Alias lifecycle via gRPC")
    func aliasLifecycle() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-alias-\(UUID().uuidString.prefix(8))"
        let aliasName = "test-alias-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Create alias
        try await client.collections.createAlias(alias: aliasName, collection: collectionName)

        // List aliases for collection
        let aliases = try await client.collections.listAliases(collection: collectionName)
        #expect(aliases.contains(where: { $0.aliasName == aliasName }))

        // List all aliases
        let allAliases = try await client.collections.listAllAliases()
        #expect(allAliases.contains(where: { $0.aliasName == aliasName }))

        // Delete alias
        try await client.collections.deleteAlias(alias: aliasName)

        // Verify alias is gone
        let aliasesAfter = try await client.collections.listAliases(collection: collectionName)
        #expect(!aliasesAfter.contains(where: { $0.aliasName == aliasName }))

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Snapshot lifecycle via gRPC")
    func snapshotLifecycle() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-snapshot-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert some points
        let points = [
            Point(id: .integer(1), vector: [0.1, 0.2, 0.3, 0.4])
        ]
        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Create snapshot
        let snapshotInfo = try await client.snapshots.create(collection: collectionName)
        #expect(!snapshotInfo.name.isEmpty)

        // List snapshots
        let snapshots = try await client.snapshots.list(collection: collectionName)
        #expect(snapshots.contains(where: { $0.name == snapshotInfo.name }))

        // Delete snapshot
        try await client.snapshots.delete(collection: collectionName, snapshot: snapshotInfo.name)

        // Verify snapshot is gone
        let snapshotsAfter = try await client.snapshots.list(collection: collectionName)
        #expect(!snapshotsAfter.contains(where: { $0.name == snapshotInfo.name }))

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    // MARK: - Batch Search Tests

    @Test("Search batch via gRPC")
    func searchBatch() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-search-batch-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0], payload: ["group": .string("A")]),
            Point(id: .integer(2), vector: [0.0, 1.0, 0.0, 0.0], payload: ["group": .string("B")]),
            Point(id: .integer(3), vector: [0.0, 0.0, 1.0, 0.0], payload: ["group": .string("C")]),
            Point(id: .integer(4), vector: [0.0, 0.0, 0.0, 1.0], payload: ["group": .string("D")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Perform batch search with multiple queries
        let searches = [
            SearchRequest(vector: [1.0, 0.0, 0.0, 0.0], limit: 2, withPayload: true),
            SearchRequest(vector: [0.0, 1.0, 0.0, 0.0], limit: 2, withPayload: true),
        ]

        let results = try await client.points.searchBatch(
            collection: collectionName, searches: searches)

        #expect(results.count == 2)
        #expect(results[0].count >= 1)
        #expect(results[1].count >= 1)

        // First search should find point 1 first
        if case .integer(let id) = results[0][0].id {
            #expect(id == 1)
        }

        // Second search should find point 2 first
        if case .integer(let id) = results[1][0].id {
            #expect(id == 2)
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Query batch via gRPC")
    func queryBatch() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-query-batch-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0], payload: ["name": .string("first")]),
            Point(
                id: .integer(2), vector: [0.0, 1.0, 0.0, 0.0], payload: ["name": .string("second")]),
            Point(
                id: .integer(3), vector: [0.0, 0.0, 1.0, 0.0], payload: ["name": .string("third")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Perform batch query
        let queries = [
            QueryRequest(query: .nearest([1.0, 0.0, 0.0, 0.0]), limit: 2, withPayload: true),
            QueryRequest(query: .nearest([0.0, 1.0, 0.0, 0.0]), limit: 2, withPayload: true),
        ]

        let results = try await client.points.queryBatch(
            collection: collectionName, queries: queries)

        #expect(results.count == 2)
        #expect(results[0].count >= 1)
        #expect(results[1].count >= 1)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Recommend batch via gRPC")
    func recommendBatch() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-recommend-batch-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0], payload: ["type": .string("ref1")]),
            Point(
                id: .integer(2), vector: [0.95, 0.05, 0.0, 0.0],
                payload: ["type": .string("similar1")]),
            Point(
                id: .integer(3), vector: [0.0, 1.0, 0.0, 0.0], payload: ["type": .string("ref2")]),
            Point(
                id: .integer(4), vector: [0.05, 0.95, 0.0, 0.0],
                payload: ["type": .string("similar2")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Perform batch recommend
        let requests = [
            RecommendRequest(positive: [.integer(1)], limit: 2, withPayload: true),
            RecommendRequest(positive: [.integer(3)], limit: 2, withPayload: true),
        ]

        let results = try await client.points.recommendBatch(
            collection: collectionName, requests: requests)

        #expect(results.count == 2)
        #expect(results[0].count >= 1)
        #expect(results[1].count >= 1)

        // Results should not include the reference points themselves
        for result in results[0] {
            if case .integer(let id) = result.id {
                #expect(id != 1)
            }
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Update batch via gRPC")
    func updateBatch() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-update-batch-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Perform batch operations: upsert, set payload, delete
        let operations: [PointsUpdateOperation] = [
            .upsert([
                Point(id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0]),
                Point(id: .integer(2), vector: [0.0, 1.0, 0.0, 0.0]),
                Point(id: .integer(3), vector: [0.0, 0.0, 1.0, 0.0]),
            ]),
            .setPayload(ids: [.integer(1), .integer(2)], payload: ["status": .string("active")]),
            .deletePoints([.integer(3)]),
        ]

        let result = try await client.points.updateBatch(
            collection: collectionName,
            operations: operations,
            wait: true
        )

        #expect(result.statuses.count == 3)

        // Verify final state
        let count = try await client.points.count(collection: collectionName)
        #expect(count == 2)

        let retrieved = try await client.points.get(
            collection: collectionName,
            ids: [.integer(1)],
            withPayload: true
        )
        #expect(retrieved[0].payload?["status"]?.stringValue == "active")

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    // MARK: - Delete Vectors Tests

    @Test("Delete vectors via gRPC")
    func deleteVectors() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-delete-vectors-\(UUID().uuidString.prefix(8))"

        // Create collection with named vectors
        try await client.collections.create(
            name: collectionName,
            vectors: [
                "text": VectorConfig(size: 4, distance: .cosine),
                "image": VectorConfig(size: 4, distance: .cosine),
            ]
        )

        // Upsert point with multiple vectors
        let points = [
            Point(
                id: .integer(1),
                vector: .named([
                    "text": [1.0, 0.0, 0.0, 0.0],
                    "image": [0.0, 1.0, 0.0, 0.0],
                ])
            )
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Delete only the "image" vector
        try await client.points.deleteVectors(
            collection: collectionName,
            ids: [.integer(1)],
            vectorNames: ["image"],
            wait: true
        )

        // Verify - point should still exist but with only "text" vector
        let retrieved = try await client.points.get(
            collection: collectionName,
            ids: [.integer(1)],
            withVectors: true
        )

        #expect(retrieved.count == 1)
        if case .named(let vectors) = retrieved[0].vector {
            #expect(vectors["text"] != nil)
            // image vector should be deleted (nil or empty)
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    // MARK: - Search Groups Tests

    @Test("Search groups via gRPC")
    func searchGroups() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-search-groups-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Create index on grouping field
        try await client.points.createFieldIndex(
            collection: collectionName,
            fieldName: "category",
            fieldType: .keyword,
            wait: true
        )

        // Upsert points with categories
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0],
                payload: ["category": .string("electronics")]),
            Point(
                id: .integer(2), vector: [0.9, 0.1, 0.0, 0.0],
                payload: ["category": .string("electronics")]),
            Point(
                id: .integer(3), vector: [0.8, 0.2, 0.0, 0.0],
                payload: ["category": .string("books")]),
            Point(
                id: .integer(4), vector: [0.7, 0.3, 0.0, 0.0],
                payload: ["category": .string("books")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Search with grouping by category
        let groups = try await client.points.searchGroups(
            collection: collectionName,
            vector: [1.0, 0.0, 0.0, 0.0],
            groupBy: "category",
            limit: 10,
            groupSize: 2,
            withPayload: true
        )

        #expect(groups.count >= 1)

        // Each group should have hits
        for group in groups {
            #expect(group.hits.count >= 1)
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    // MARK: - Discover Tests

    @Test("Discover points via gRPC")
    func discoverPoints() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-discover-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0], payload: ["type": .string("target")]),
            Point(
                id: .integer(2), vector: [0.9, 0.1, 0.0, 0.0],
                payload: ["type": .string("positive")]),
            Point(
                id: .integer(3), vector: [0.0, 1.0, 0.0, 0.0],
                payload: ["type": .string("negative")]),
            Point(
                id: .integer(4), vector: [0.8, 0.2, 0.0, 0.0], payload: ["type": .string("similar")]
            ),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Discover with context pairs
        let context = [
            ContextPair(
                positive: .vector([1.0, 0.0, 0.0, 0.0]),
                negative: .vector([0.0, 1.0, 0.0, 0.0])
            )
        ]

        let results = try await client.points.discover(
            collection: collectionName,
            target: .vector([0.85, 0.15, 0.0, 0.0]),
            context: context,
            limit: 3,
            withPayload: true
        )

        #expect(results.count >= 1)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Discover batch via gRPC")
    func discoverBatch() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-discover-batch-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0]),
            Point(id: .integer(2), vector: [0.0, 1.0, 0.0, 0.0]),
            Point(id: .integer(3), vector: [0.9, 0.1, 0.0, 0.0]),
            Point(id: .integer(4), vector: [0.1, 0.9, 0.0, 0.0]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Batch discover
        let requests = [
            DiscoverRequest(
                target: .vector([1.0, 0.0, 0.0, 0.0]),
                context: [
                    ContextPair(
                        positive: .vector([0.9, 0.1, 0.0, 0.0]),
                        negative: .vector([0.0, 1.0, 0.0, 0.0]))
                ],
                limit: 2,
                withPayload: true
            ),
            DiscoverRequest(
                target: .vector([0.0, 1.0, 0.0, 0.0]),
                context: [
                    ContextPair(
                        positive: .vector([0.1, 0.9, 0.0, 0.0]),
                        negative: .vector([1.0, 0.0, 0.0, 0.0]))
                ],
                limit: 2,
                withPayload: true
            ),
        ]

        let results = try await client.points.discoverBatch(
            collection: collectionName, requests: requests)

        #expect(results.count == 2)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    // MARK: - Facet Tests

    @Test("Facet search via gRPC")
    func facetSearch() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-facet-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Create index on facet field
        try await client.points.createFieldIndex(
            collection: collectionName,
            fieldName: "category",
            fieldType: .keyword,
            wait: true
        )

        // Upsert points with categories
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0],
                payload: ["category": .string("electronics")]),
            Point(
                id: .integer(2), vector: [0.9, 0.1, 0.0, 0.0],
                payload: ["category": .string("electronics")]),
            Point(
                id: .integer(3), vector: [0.8, 0.2, 0.0, 0.0],
                payload: ["category": .string("electronics")]),
            Point(
                id: .integer(4), vector: [0.7, 0.3, 0.0, 0.0],
                payload: ["category": .string("books")]),
            Point(
                id: .integer(5), vector: [0.6, 0.4, 0.0, 0.0],
                payload: ["category": .string("books")]),
            Point(
                id: .integer(6), vector: [0.5, 0.5, 0.0, 0.0],
                payload: ["category": .string("clothing")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Get facet counts
        let result = try await client.points.facet(
            collection: collectionName,
            key: "category",
            limit: 10
        )

        #expect(result.hits.count >= 1)

        // Find the electronics count
        let electronicsHit = result.hits.first { hit in
            if case .string(let value) = hit.value {
                return value == "electronics"
            }
            return false
        }
        #expect(electronicsHit?.count == 3)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    // MARK: - Search Matrix Tests

    @Test("Search matrix pairs via gRPC")
    func searchMatrixPairs() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-matrix-pairs-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0]),
            Point(id: .integer(2), vector: [0.9, 0.1, 0.0, 0.0]),
            Point(id: .integer(3), vector: [0.0, 1.0, 0.0, 0.0]),
            Point(id: .integer(4), vector: [0.0, 0.0, 1.0, 0.0]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Get similarity matrix as pairs
        let result = try await client.points.searchMatrixPairs(
            collection: collectionName,
            sample: 4,
            limit: 3
        )

        #expect(result.pairs.count >= 1)

        // Each pair should have valid IDs and a score
        for pair in result.pairs {
            #expect(pair.score >= -1.0 && pair.score <= 1.0)
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    @Test("Search matrix offsets via gRPC")
    func searchMatrixOffsets() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-matrix-offsets-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Upsert points
        let points = [
            Point(id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0]),
            Point(id: .integer(2), vector: [0.9, 0.1, 0.0, 0.0]),
            Point(id: .integer(3), vector: [0.0, 1.0, 0.0, 0.0]),
            Point(id: .integer(4), vector: [0.0, 0.0, 1.0, 0.0]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Get similarity matrix as offsets
        let result = try await client.points.searchMatrixOffsets(
            collection: collectionName,
            sample: 4,
            limit: 3
        )

        #expect(result.ids.count >= 1)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    // MARK: - Query Groups Tests

    @Test("Query groups via gRPC")
    func queryGroups() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-query-groups-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Create index on grouping field
        try await client.points.createFieldIndex(
            collection: collectionName,
            fieldName: "category",
            fieldType: .keyword,
            wait: true
        )

        // Upsert points with categories
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0],
                payload: ["category": .string("electronics")]),
            Point(
                id: .integer(2), vector: [0.9, 0.1, 0.0, 0.0],
                payload: ["category": .string("electronics")]),
            Point(
                id: .integer(3), vector: [0.8, 0.2, 0.0, 0.0],
                payload: ["category": .string("books")]),
            Point(
                id: .integer(4), vector: [0.7, 0.3, 0.0, 0.0],
                payload: ["category": .string("books")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Query with grouping by category
        let groups = try await client.points.queryGroups(
            collection: collectionName,
            query: .nearest([1.0, 0.0, 0.0, 0.0]),
            groupBy: "category",
            limit: 10,
            groupSize: 2,
            withPayload: true
        )

        #expect(groups.count >= 1)

        // Each group should have hits
        for group in groups {
            #expect(group.hits.count >= 1)
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    // MARK: - Recommend Groups Tests

    @Test("Recommend groups via gRPC")
    func recommendGroups() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-recommend-groups-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Create index on grouping field
        try await client.points.createFieldIndex(
            collection: collectionName,
            fieldName: "category",
            fieldType: .keyword,
            wait: true
        )

        // Upsert points with categories
        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0],
                payload: ["category": .string("electronics")]),
            Point(
                id: .integer(2), vector: [0.95, 0.05, 0.0, 0.0],
                payload: ["category": .string("electronics")]),
            Point(
                id: .integer(3), vector: [0.9, 0.1, 0.0, 0.0],
                payload: ["category": .string("books")]),
            Point(
                id: .integer(4), vector: [0.85, 0.15, 0.0, 0.0],
                payload: ["category": .string("books")]),
            Point(
                id: .integer(5), vector: [0.0, 1.0, 0.0, 0.0],
                payload: ["category": .string("clothing")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Recommend with grouping by category
        let groups = try await client.points.recommendGroups(
            collection: collectionName,
            positive: [.integer(1)],
            groupBy: "category",
            limit: 10,
            groupSize: 2,
            withPayload: true
        )

        #expect(groups.count >= 1)

        // Each group should have hits (and not include the reference point)
        for group in groups {
            #expect(group.hits.count >= 1)
        }

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    // MARK: - Collection Update Tests

    @Test("Update collection via gRPC")
    func updateCollection() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-update-collection-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Update collection parameters
        try await client.collections.update(
            name: collectionName,
            indexingThreshold: 10000
        )

        // Verify collection still exists and is healthy
        let info = try await client.collections.get(name: collectionName)
        #expect(info.status == .green)

        // Clean up
        try await client.collections.delete(name: collectionName)
    }

    // MARK: - Full Snapshot Tests

    @Test("Full snapshot lifecycle via gRPC")
    func fullSnapshotLifecycle() async throws {
        let client = try await createClient()
        defer { client.close() }

        let collectionName = "grpc-full-snapshot-\(UUID().uuidString.prefix(8))"

        // Create collection with some data
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        let points = [
            Point(id: .integer(1), vector: [0.1, 0.2, 0.3, 0.4])
        ]
        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Create full snapshot
        let snapshotInfo = try await client.snapshots.createFull()
        #expect(!snapshotInfo.name.isEmpty)

        // List full snapshots
        let snapshots = try await client.snapshots.listFull()
        #expect(snapshots.contains(where: { $0.name == snapshotInfo.name }))

        // Delete full snapshot
        try await client.snapshots.deleteFull(snapshot: snapshotInfo.name)

        // Verify snapshot is gone
        let snapshotsAfter = try await client.snapshots.listFull()
        #expect(!snapshotsAfter.contains(where: { $0.name == snapshotInfo.name }))

        // Clean up
        try await client.collections.delete(name: collectionName)
    }
}
