import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Internal service for query operations.
internal final class QueryService: Sendable {
    private let base: PointsServiceBase

    init(base: PointsServiceBase) {
        self.base = base
    }

    /// Universal query API - performs various types of queries.
    func query(
        collection: String,
        query: QueryInput?,
        prefetch: [PrefetchQuery],
        using: String?,
        filter: Filter?,
        limit: UInt64,
        offset: UInt64?,
        scoreThreshold: Float?,
        withPayload: Bool,
        withVectors: Bool
    ) async throws -> [ScoredPoint] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_QueryPoints()
        grpcRequest.collectionName = collection
        grpcRequest.prefetch = prefetch.map { $0.grpc }
        grpcRequest.limit = limit

        if let query = query {
            grpcRequest.query = query.grpc
        }

        if let using = using {
            grpcRequest.using = using
        }

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        if let offset = offset {
            grpcRequest.offset = offset
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
            let response: Qdrant_QueryResponse = try await client.query(request: request)
            return response.result.compactMap { ScoredPoint(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Performs multiple queries in a single batch request.
    func queryBatch(
        collection: String,
        queries: [QueryRequest]
    ) async throws -> [[ScoredPoint]] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_QueryBatchPoints()
        grpcRequest.collectionName = collection
        grpcRequest.queryPoints = queries.map { queryReq in
            var qp = Qdrant_QueryPoints()
            qp.collectionName = collection
            qp.prefetch = queryReq.prefetch.map { $0.grpc }
            qp.limit = queryReq.limit

            if let query = queryReq.query {
                qp.query = query.grpc
            }

            if let using = queryReq.using {
                qp.using = using
            }

            if let filter = queryReq.filter {
                qp.filter = filter.grpc
            }

            if let scoreThreshold = queryReq.scoreThreshold {
                qp.scoreThreshold = scoreThreshold
            }

            var payloadSelector = Qdrant_WithPayloadSelector()
            payloadSelector.enable = queryReq.withPayload
            qp.withPayload = payloadSelector

            return qp
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_QueryBatchResponse = try await client.queryBatch(request: request)
            return response.result.map { batchResult in
                batchResult.result.compactMap { ScoredPoint(grpc: $0) }
            }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Performs a grouped query.
    func queryGroups(
        collection: String,
        query: QueryInput?,
        groupBy: String,
        limit: UInt64,
        groupSize: UInt64,
        prefetch: [PrefetchQuery],
        using: String?,
        filter: Filter?,
        scoreThreshold: Float?,
        withPayload: Bool
    ) async throws -> [PointGroup] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_QueryPointGroups()
        grpcRequest.collectionName = collection
        grpcRequest.groupBy = groupBy
        grpcRequest.limit = limit
        grpcRequest.groupSize = groupSize
        grpcRequest.prefetch = prefetch.map { $0.grpc }

        if let query = query {
            grpcRequest.query = query.grpc
        }

        if let using = using {
            grpcRequest.using = using
        }

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
            let response: Qdrant_QueryGroupsResponse = try await client.queryGroups(
                request: request)
            return response.result.groups.map { PointGroup(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }
}
