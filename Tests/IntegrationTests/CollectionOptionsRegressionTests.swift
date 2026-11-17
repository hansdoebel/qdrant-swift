import Foundation
import Testing
import QdrantCore
import QdrantGRPC

@Suite("Collection options regressions", .serialized)
struct CollectionOptionsRegressionTests {
    private func createClient() async throws -> QdrantGRPCClient {
        let config = try IntegrationTestConfig.load()
        let url = try #require(URL(string: config.url))
        let host = try #require(url.host)
        let port = Int(ProcessInfo.processInfo.environment["QDRANT_GRPC_PORT"] ?? "6334") ?? 6334
        return try await QdrantGRPCClient(host: host, port: port, apiKey: config.apiKey, useTLS: url.scheme == "https")
    }

    @Test func duplicateOptionsCreationPreservesTypedError() async throws {
        let client = try await createClient()
        defer { client.close() }
        let name = "chunky-duplicate-" + UUID().uuidString.lowercased()
        let options = CollectionOptions(vectors: .single(VectorConfig(size: 3, distance: .cosine)))
        try await client.collections.create(name: name, options: options)
        do {
            do {
                try await client.collections.create(name: name, options: options)
                Issue.record("Duplicate creation should fail")
            } catch QdrantError.collectionAlreadyExists(let message) {
                #expect(message.contains(name))
            }
            #expect(try await client.collections.exists(name: name))
        } catch {
            try? await client.collections.delete(name: name)
            throw error
        }
        try await client.collections.delete(name: name)
    }

    @Test func strictModeEnforcesBatchLimitOnlyWhenEnabled() async throws {
        let client = try await createClient()
        defer { client.close() }
        for enabled in [false, true] {
            let name = "chunky-strict-" + UUID().uuidString.lowercased()
            let options = CollectionOptions(vectors: .single(VectorConfig(size: 3, distance: .cosine)), strictMode: StrictModeConfig(enabled: enabled, searchMaxBatchsize: 1))
            try await client.collections.create(name: name, options: options)
            do {
                let query = QueryRequest(query: .nearest(.dense([1, 0, 0])))
                let allowed = try await client.points.queryBatch(collection: name, queries: [query])
                #expect(allowed.count == 1)
                if enabled {
                    do {
                        _ = try await client.points.queryBatch(collection: name, queries: [query, query])
                        Issue.record("Enabled strict mode accepted an oversized batch")
                    } catch {
                        #expect(error.localizedDescription.lowercased().contains("batch"))
                    }
                } else {
                    let allowedBatch = try await client.points.queryBatch(collection: name, queries: [query, query])
                    #expect(allowedBatch.count == 2)
                }
            } catch {
                try? await client.collections.delete(name: name)
                throw error
            }
            try await client.collections.delete(name: name)
        }
    }

}
