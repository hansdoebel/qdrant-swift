import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Internal service for CRUD operations on points.
internal final class PointsCRUDService: Sendable {
    private let base: PointsServiceBase

    init(base: PointsServiceBase) {
        self.base = base
    }

    /// Inserts or updates points in a collection.
    func upsert(
        collection: String,
        points: [Point],
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_UpsertPoints()
        grpcRequest.collectionName = collection
        grpcRequest.points = points.map { $0.grpc }
        grpcRequest.wait = wait

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.upsert(request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Upsert failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Retrieves points by their IDs.
    func get(
        collection: String,
        ids: [PointID],
        withPayload: Bool,
        withVectors: Bool
    ) async throws -> [RetrievedPoint] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_GetPoints()
        grpcRequest.collectionName = collection
        grpcRequest.ids = ids.map { $0.grpc }

        var payloadSelector = Qdrant_WithPayloadSelector()
        payloadSelector.enable = withPayload
        grpcRequest.withPayload = payloadSelector

        var vectorsSelector = Qdrant_WithVectorsSelector()
        vectorsSelector.enable = withVectors
        grpcRequest.withVectors = vectorsSelector

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_GetResponse = try await client.get(request: request)
            return response.result.compactMap { RetrievedPoint(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Deletes points by their IDs.
    func delete(
        collection: String,
        ids: [PointID],
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var pointsSelector = Qdrant_PointsSelector()
        var idsSelector = Qdrant_PointsIdsList()
        idsSelector.ids = ids.map { $0.grpc }
        pointsSelector.points = idsSelector

        var grpcRequest = Qdrant_DeletePoints()
        grpcRequest.collectionName = collection
        grpcRequest.points = pointsSelector
        grpcRequest.wait = wait

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.delete(request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Delete failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Deletes points matching a filter.
    func delete(
        collection: String,
        filter: Filter,
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var pointsSelector = Qdrant_PointsSelector()
        pointsSelector.filter = filter.grpc

        var grpcRequest = Qdrant_DeletePoints()
        grpcRequest.collectionName = collection
        grpcRequest.points = pointsSelector
        grpcRequest.wait = wait

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.delete(request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Delete failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Scrolls through points in a collection.
    func scroll(
        collection: String,
        filter: Filter?,
        limit: UInt32,
        offset: PointID?,
        withPayload: Bool,
        withVectors: Bool
    ) async throws -> ScrollResult {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_ScrollPoints()
        grpcRequest.collectionName = collection
        grpcRequest.limit = limit

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        if let offset = offset {
            grpcRequest.offset = offset.grpc
        }

        var payloadSelector = Qdrant_WithPayloadSelector()
        payloadSelector.enable = withPayload
        grpcRequest.withPayload = payloadSelector

        var vectorsSelector = Qdrant_WithVectorsSelector()
        vectorsSelector.enable = withVectors
        grpcRequest.withVectors = vectorsSelector

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_ScrollResponse = try await client.scroll(request: request)
            let points = response.result.compactMap { RetrievedPoint(grpc: $0) }
            let nextOffset =
                response.hasNextPageOffset ? PointID(grpc: response.nextPageOffset) : nil
            return ScrollResult(points: points, nextPageOffset: nextOffset)
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Counts the number of points in a collection.
    func count(
        collection: String,
        filter: Filter?,
        exact: Bool
    ) async throws -> UInt64 {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_CountPoints()
        grpcRequest.collectionName = collection
        grpcRequest.exact = exact

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_CountResponse = try await client.count(request: request)
            return response.result.count
        } catch {
            throw QdrantError.from(error)
        }
    }
}
