import Testing
import QdrantCore
import QdrantMocks

@Suite("Mock reuse")
struct MockResetTests {
    @Test func resetClearsModernTracking() async throws {
        let points = MockPointsService()
        try await points.upsert(collection: "books", points: [], wait: true, updateMode: .insertOnly)
        try await points.createVectorName(collection: "books", name: "title", spec: .dense(DenseVectorSpec(size: 8, distance: .dot)), wait: true)
        try await points.createFieldIndex(collection: "books", fieldName: "title", schema: .text(TextIndexOptions(tokenizer: .code)), wait: true)
        #expect(points.lastUpdateMode == .insertOnly)
        #expect(points.vectorNameCalls.count == 1)
        #expect(points.createFieldSchemaCalls.count == 1)
        points.reset()
        #expect(points.lastUpdateMode == nil)
        #expect(points.vectorNameCalls.isEmpty)
        #expect(points.createFieldSchemaCalls.isEmpty)
        try await points.deleteVectorName(collection: "other", name: "body", wait: true)
        #expect(points.vectorNameCalls.count == 1)
        #expect(points.vectorNameCalls.first?.collection == "other")

        let collections = MockCollectionsService()
        let options = CollectionOptions(vectors: .single(VectorConfig(size: 8, distance: .dot)))
        try await collections.create(name: "books", options: options)
        #expect(collections.optionCreates.count == 1)
        collections.reset()
        #expect(collections.optionCreates.isEmpty)
        try await collections.create(name: "other", options: options)
        #expect(collections.optionCreates.count == 1)
    }
}
