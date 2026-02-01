import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Internal service for search operations.
internal final class SearchService: Sendable {
    private let base: PointsServiceBase

    init(base: PointsServiceBase) {
        self.base = base
    }

    /// Searches for similar vectors.
    func search(
        collection: String,
        vector: [Float],
        limit: UInt64,
        filter: Filter?,
        scoreThreshold: Float?,
        offset: UInt64?,
        withPayload: Bool,
        withVectors: Bool,
        vectorName: String?
    ) async throws -> [ScoredPoint] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_SearchPoints()
        grpcRequest.collectionName = collection
        grpcRequest.vector = vector
        grpcRequest.limit = limit

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        if let scoreThreshold = scoreThreshold {
            grpcRequest.scoreThreshold = scoreThreshold
        }

        if let offset = offset {
            grpcRequest.offset = offset
        }

        if let vectorName = vectorName {
            grpcRequest.vectorName = vectorName
        }

        var payloadSelector = Qdrant_WithPayloadSelector()
        payloadSelector.enable = withPayload
        grpcRequest.withPayload = payloadSelector

        var vectorsSelector = Qdrant_WithVectorsSelector()
        vectorsSelector.enable = withVectors
        grpcRequest.withVectors = vectorsSelector

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_SearchResponse = try await client.search(request: request)
            return response.result.compactMap { ScoredPoint(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Performs multiple searches in a single request.
    func searchBatch(
        collection: String,
        searches: [SearchRequest]
    ) async throws -> [[ScoredPoint]] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_SearchBatchPoints()
        grpcRequest.collectionName = collection
        grpcRequest.searchPoints = searches.map { search in
            var searchPoints = Qdrant_SearchPoints()
            searchPoints.collectionName = collection
            searchPoints.vector = search.vector
            searchPoints.limit = search.limit

            if let filter = search.filter {
                searchPoints.filter = filter.grpc
            }

            if let scoreThreshold = search.scoreThreshold {
                searchPoints.scoreThreshold = scoreThreshold
            }

            var payloadSelector = Qdrant_WithPayloadSelector()
            payloadSelector.enable = search.withPayload
            searchPoints.withPayload = payloadSelector

            return searchPoints
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_SearchBatchResponse = try await client.searchBatch(
                request: request)
            return response.result.map { batchResult in
                batchResult.result.compactMap { ScoredPoint(grpc: $0) }
            }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Searches for groups of similar vectors.
    func searchGroups(
        collection: String,
        vector: [Float],
        groupBy: String,
        limit: UInt32,
        groupSize: UInt32,
        filter: Filter?,
        withPayload: Bool
    ) async throws -> [PointGroup] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_SearchPointGroups()
        grpcRequest.collectionName = collection
        grpcRequest.vector = vector
        grpcRequest.groupBy = groupBy
        grpcRequest.limit = limit
        grpcRequest.groupSize = groupSize

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        var payloadSelector = Qdrant_WithPayloadSelector()
        payloadSelector.enable = withPayload
        grpcRequest.withPayload = payloadSelector

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_SearchGroupsResponse = try await client.searchGroups(
                request: request)
            return response.result.groups.map { PointGroup(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Computes distance matrix between sampled points (pairs format).
    func searchMatrixPairs(
        collection: String,
        filter: Filter?,
        sample: UInt64,
        limit: UInt64,
        using: String?
    ) async throws -> SearchMatrixPairsResult {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_SearchMatrixPoints()
        grpcRequest.collectionName = collection
        grpcRequest.sample = sample
        grpcRequest.limit = limit

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        if let using = using {
            grpcRequest.using = using
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_SearchMatrixPairsResponse = try await client.searchMatrixPairs(
                request: request)
            return SearchMatrixPairsResult(grpc: response)
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Computes distance matrix between sampled points (offsets format).
    func searchMatrixOffsets(
        collection: String,
        filter: Filter?,
        sample: UInt64,
        limit: UInt64,
        using: String?
    ) async throws -> SearchMatrixOffsetsResult {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_SearchMatrixPoints()
        grpcRequest.collectionName = collection
        grpcRequest.sample = sample
        grpcRequest.limit = limit

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        if let using = using {
            grpcRequest.using = using
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_SearchMatrixOffsetsResponse = try await client.searchMatrixOffsets(
                request: request)
            return SearchMatrixOffsetsResult(grpc: response)
        } catch {
            throw QdrantError.from(error)
        }
    }
}
