import Testing

@testable import QdrantCore
@testable import QdrantGRPC
@testable import QdrantMocks
import QdrantProto

@Suite("Collection and point gRPC mapping")
struct CollectionParityTests {
    @Test("TurboQuant datatype and quantization map onto the proto")
    func turboQuant() {
        let config = VectorConfig(size: 128, distance: .cosine, datatype: .turbo16, memory: .cached)
        let params = config.grpcParams
        #expect(params.datatype == .turbo16)
        #expect(params.memory == .cached)

        let options = CollectionOptions(
            vectors: .single(config),
            quantization: .turbo(TurboQuantization(bits: .bits8, memory: .cold)),
            payload: PayloadStorageParams(memory: .cached),
            idTracker: IdTrackerParams(memory: .cold),
            strictMode: StrictModeConfig(requireTenantFilter: true, searchMaxBatchsize: 32)
        )
        let request = options.grpc
        #expect(request.quantizationConfig.turboquant.bits == .bits8)
        #expect(request.quantizationConfig.turboquant.memory == .cold)
        #expect(request.payload.memory == .cached)
        #expect(request.idTracker.memory == .cold)
        #expect(request.strictModeConfig.requireTenantFilter)
        #expect(request.strictModeConfig.searchMaxBatchsize == 32)
    }

    @Test("Collection info keeps created_at and the update queue")
    func collectionInfo() {
        var info = Qdrant_CollectionInfo()
        info.createdAt.seconds = 1_700_000_000
        info.updateQueue.length = 4
        info.updateQueue.deferredPoints = 2
        let mapped = CollectionInfo(name: "books", grpc: info)
        #expect(mapped.createdAt?.timeIntervalSince1970 == 1_700_000_000)
        #expect(mapped.updateQueue?.length == 4)
        #expect(mapped.updateQueue?.deferredPoints == 2)
    }

    @Test("Upsert mode and named vector creation are recorded")
    func points() async throws {
        #expect(UpdateMode.insertOnly.grpc == .insertOnly)
        #expect(UpdateMode.updateOnly.grpc == .updateOnly)
        let dense = NamedVectorSpec.dense(DenseVectorSpec(size: 8, distance: .dot, datatype: .turbo8))
        #expect(dense.dense?.datatype == .turbo8)
        let sparse = NamedVectorSpec.sparse(SparseVectorSpec(modifier: .idf, datatype: .float32))
        #expect(sparse.sparse?.modifier == .idf)

        let mock = MockPointsService()
        try await mock.upsert(collection: "books", points: [], wait: true, updateMode: .insertOnly)
        try await mock.createVectorName(collection: "books", name: "title", spec: dense, wait: true)
        try await mock.deleteVectorName(collection: "books", name: "title", wait: true)
        #expect(mock.lastUpdateMode == .insertOnly)
        #expect(mock.vectorNameCalls.count == 2)
    }
}
