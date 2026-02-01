import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Internal service for recommend operations.
internal final class RecommendService: Sendable {
    private let base: PointsServiceBase

    init(base: PointsServiceBase) {
        self.base = base
    }

    /// Finds points similar to the given positive examples and dissimilar to negative examples.
    func recommend(
        collection: String,
        positive: [PointID],
        negative: [PointID],
        limit: UInt64,
        filter: Filter?,
        scoreThreshold: Float?,
        withPayload: Bool,
        withVectors: Bool
    ) async throws -> [ScoredPoint] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_RecommendPoints()
        grpcRequest.collectionName = collection
        grpcRequest.positive = positive.map { $0.grpc }
        grpcRequest.negative = negative.map { $0.grpc }
        grpcRequest.limit = limit

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        if let scoreThreshold = scoreThreshold {
            grpcRequest.scoreThreshold = scoreThreshold
        }

        var payloadSelector = Qdrant_WithPayloadSelector()
        payloadSelector.enable = withPayload
        grpcRequest.withPayload = payloadSelector

        var vectorsSelector = Qdrant_WithVectorsSelector()
        vectorsSelector.enable = withVectors
        grpcRequest.withVectors = vectorsSelector

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_RecommendResponse = try await client.recommend(request: request)
            return response.result.compactMap { ScoredPoint(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Performs multiple recommend requests in a single batch.
    func recommendBatch(
        collection: String,
        requests: [RecommendRequest]
    ) async throws -> [[ScoredPoint]] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_RecommendBatchPoints()
        grpcRequest.collectionName = collection
        grpcRequest.recommendPoints = requests.map { req in
            var recommendPoints = Qdrant_RecommendPoints()
            recommendPoints.collectionName = collection
            recommendPoints.positive = req.positive.map { $0.grpc }
            recommendPoints.negative = req.negative.map { $0.grpc }
            recommendPoints.limit = req.limit

            if let filter = req.filter {
                recommendPoints.filter = filter.grpc
            }

            var payloadSelector = Qdrant_WithPayloadSelector()
            payloadSelector.enable = req.withPayload
            recommendPoints.withPayload = payloadSelector

            return recommendPoints
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_RecommendBatchResponse = try await client.recommendBatch(
                request: request)
            return response.result.map { batchResult in
                batchResult.result.compactMap { ScoredPoint(grpc: $0) }
            }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Finds groups of points similar to positive examples.
    func recommendGroups(
        collection: String,
        positive: [PointID],
        negative: [PointID],
        groupBy: String,
        limit: UInt32,
        groupSize: UInt32,
        filter: Filter?,
        scoreThreshold: Float?,
        withPayload: Bool
    ) async throws -> [PointGroup] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_RecommendPointGroups()
        grpcRequest.collectionName = collection
        grpcRequest.positive = positive.map { $0.grpc }
        grpcRequest.negative = negative.map { $0.grpc }
        grpcRequest.groupBy = groupBy
        grpcRequest.limit = limit
        grpcRequest.groupSize = groupSize

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        if let scoreThreshold = scoreThreshold {
            grpcRequest.scoreThreshold = scoreThreshold
        }

        var payloadSelector = Qdrant_WithPayloadSelector()
        payloadSelector.enable = withPayload
        grpcRequest.withPayload = payloadSelector

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_RecommendGroupsResponse = try await client.recommendGroups(
                request: request)
            return response.result.groups.map { PointGroup(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }
}
