import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Internal service for payload operations.
internal final class PayloadService: Sendable {
    private let base: PointsServiceBase

    init(base: PointsServiceBase) {
        self.base = base
    }

    /// Sets payload values for specific points.
    func setPayload(
        collection: String,
        ids: [PointID],
        payload: [String: PayloadValue],
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var pointsSelector = Qdrant_PointsSelector()
        var idsSelector = Qdrant_PointsIdsList()
        idsSelector.ids = ids.map { $0.grpc }
        pointsSelector.points = idsSelector

        var grpcRequest = Qdrant_SetPayloadPoints()
        grpcRequest.collectionName = collection
        grpcRequest.pointsSelector = pointsSelector
        grpcRequest.wait = wait

        for (key, value) in payload {
            grpcRequest.payload[key] = value.grpc
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.setPayload(
                request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Set payload failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Overwrites the entire payload for specific points.
    func overwritePayload(
        collection: String,
        ids: [PointID],
        payload: [String: PayloadValue],
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var pointsSelector = Qdrant_PointsSelector()
        var idsSelector = Qdrant_PointsIdsList()
        idsSelector.ids = ids.map { $0.grpc }
        pointsSelector.points = idsSelector

        var grpcRequest = Qdrant_SetPayloadPoints()
        grpcRequest.collectionName = collection
        grpcRequest.pointsSelector = pointsSelector
        grpcRequest.wait = wait

        for (key, value) in payload {
            grpcRequest.payload[key] = value.grpc
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.overwritePayload(
                request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Overwrite payload failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Deletes specific payload keys from points.
    func deletePayload(
        collection: String,
        ids: [PointID],
        keys: [String],
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var pointsSelector = Qdrant_PointsSelector()
        var idsSelector = Qdrant_PointsIdsList()
        idsSelector.ids = ids.map { $0.grpc }
        pointsSelector.points = idsSelector

        var grpcRequest = Qdrant_DeletePayloadPoints()
        grpcRequest.collectionName = collection
        grpcRequest.pointsSelector = pointsSelector
        grpcRequest.keys = keys
        grpcRequest.wait = wait

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.deletePayload(
                request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Delete payload failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Clears all payload from points.
    func clearPayload(
        collection: String,
        ids: [PointID],
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var pointsSelector = Qdrant_PointsSelector()
        var idsSelector = Qdrant_PointsIdsList()
        idsSelector.ids = ids.map { $0.grpc }
        pointsSelector.points = idsSelector

        var grpcRequest = Qdrant_ClearPayloadPoints()
        grpcRequest.collectionName = collection
        grpcRequest.points = pointsSelector
        grpcRequest.wait = wait

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.clearPayload(
                request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Clear payload failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }
}
