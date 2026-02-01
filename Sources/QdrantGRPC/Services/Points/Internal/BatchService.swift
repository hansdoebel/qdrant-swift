import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Internal service for batch update operations.
internal final class BatchService: Sendable {
    private let base: PointsServiceBase

    init(base: PointsServiceBase) {
        self.base = base
    }

    /// Performs multiple update operations in a single batch.
    func updateBatch(
        collection: String,
        operations: [PointsUpdateOperation],
        wait: Bool
    ) async throws -> BatchUpdateResult {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_UpdateBatchPoints()
        grpcRequest.collectionName = collection
        grpcRequest.wait = wait
        grpcRequest.operations = operations.map { $0.grpc }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_UpdateBatchResponse = try await client.updateBatch(
                request: request)
            return BatchUpdateResult(grpc: response)
        } catch {
            throw QdrantError.from(error)
        }
    }
}
