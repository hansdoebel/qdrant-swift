import Foundation
import Testing

@testable import QdrantCore
@testable import QdrantREST

/// Minimal validation tests for Qdrant Cloud REST client.
/// Validates core SDK functionality against a real Qdrant Cloud instance.
@Suite("Qdrant Cloud Validation", .serialized)
struct CloudValidationTests {

    // MARK: - Helper Functions

    private func createClient() throws -> QdrantRESTClient {
        let config = try IntegrationTestConfig.load()

        guard let url = URL(string: config.url) else {
            throw TestError.invalidURL
        }

        let host = url.host ?? "localhost"
        let port = url.port ?? 6333
        let useTLS = url.scheme == "https"

        return try QdrantRESTClient(
            host: host,
            port: port,
            useTLS: useTLS,
            apiKey: config.apiKey
        )
    }

    enum TestError: Error {
        case invalidURL
    }

    // MARK: - Validation Tests

    @Test("1. Connectivity check - verify connection and authentication")
    func connectivityCheck() async throws {
        let client = try createClient()

        // Use telemetry endpoint which returns structured JSON with version info
        let telemetry = try await client.telemetry()

        #expect(telemetry.result?.app?.name == "qdrant")
        #expect(telemetry.result?.app?.version != nil)
    }

    @Test("2. Collection lifecycle - create, verify, delete")
    func collectionLifecycle() async throws {
        let client = try createClient()
        let collectionName = "cloud-validation-\(UUID().uuidString.prefix(8))"

        // Create collection
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        // Verify exists
        let exists = try await client.collections.exists(name: collectionName)
        #expect(exists == true)

        // Get info
        let info = try await client.collections.get(name: collectionName)
        #expect(info.status == .green)

        // Delete
        try await client.collections.delete(name: collectionName)

        // Verify deleted
        let existsAfter = try await client.collections.exists(name: collectionName)
        #expect(existsAfter == false)
    }

    @Test("3. Points upsert and get")
    func pointsUpsertAndGet() async throws {
        let client = try createClient()
        let collectionName = "cloud-validation-\(UUID().uuidString.prefix(8))"

        // Setup
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
                payload: ["name": .string("first"), "value": .integer(100)]
            ),
            Point(
                id: .integer(2),
                vector: [0.5, 0.6, 0.7, 0.8],
                payload: ["name": .string("second"), "value": .integer(200)]
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
        #expect(point1?.payload?["name"]?.stringValue == "first")
        #expect(point1?.payload?["value"]?.integerValue == 100)

        // Cleanup
        try await client.collections.delete(name: collectionName)
    }

    @Test("4. Vector search")
    func vectorSearch() async throws {
        let client = try createClient()
        let collectionName = "cloud-validation-\(UUID().uuidString.prefix(8))"

        // Setup
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        let points = [
            Point(
                id: .integer(1), vector: [1.0, 0.0, 0.0, 0.0], payload: ["name": .string("north")]),
            Point(
                id: .integer(2), vector: [0.0, 1.0, 0.0, 0.0], payload: ["name": .string("east")]),
            Point(id: .integer(3), vector: [0.0, 0.0, 1.0, 0.0], payload: ["name": .string("up")]),
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Search for vector similar to point 1
        let results = try await client.points.search(
            collection: collectionName,
            vector: [0.99, 0.01, 0.0, 0.0],
            limit: 2,
            withPayload: true
        )

        #expect(results.count == 2)

        // First result should be point 1 (most similar)
        if case .integer(let id) = results[0].id {
            #expect(id == 1)
        }
        #expect(results[0].payload?["name"]?.stringValue == "north")

        // Cleanup
        try await client.collections.delete(name: collectionName)
    }

    @Test("5. Payload operations")
    func payloadOperations() async throws {
        let client = try createClient()
        let collectionName = "cloud-validation-\(UUID().uuidString.prefix(8))"

        // Setup
        try await client.collections.create(
            name: collectionName,
            vectorSize: 4,
            distance: .cosine
        )

        let points = [
            Point(id: .integer(1), vector: [0.1, 0.2, 0.3, 0.4])
        ]

        try await client.points.upsert(collection: collectionName, points: points, wait: true)

        // Set payload
        try await client.points.setPayload(
            collection: collectionName,
            ids: [.integer(1)],
            payload: ["category": .string("test"), "score": .double(95.5)],
            wait: true
        )

        // Verify payload
        let retrieved = try await client.points.get(
            collection: collectionName,
            ids: [.integer(1)],
            withPayload: true
        )

        #expect(retrieved[0].payload?["category"]?.stringValue == "test")
        #expect(retrieved[0].payload?["score"]?.doubleValue == 95.5)

        // Cleanup
        try await client.collections.delete(name: collectionName)
    }
}
