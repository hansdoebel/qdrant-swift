import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Internal service for vector operations.
internal final class VectorService: Sendable {
    private let base: PointsServiceBase

    init(base: PointsServiceBase) {
        self.base = base
    }

    /// Updates vectors for specific points.
    func updateVectors(
        collection: String,
        points: [(id: PointID, vector: VectorData)],
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_UpdatePointVectors()
        grpcRequest.collectionName = collection
        grpcRequest.wait = wait
        grpcRequest.points = points.map { point in
            var pv = Qdrant_PointVectors()
            pv.id = point.id.grpc
            pv.vectors = point.vector.grpc
            return pv
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.updateVectors(
                request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Update vectors failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Deletes specific named vectors from points.
    func deleteVectors(
        collection: String,
        ids: [PointID],
        vectorNames: [String],
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_DeletePointVectors()
        grpcRequest.collectionName = collection
        grpcRequest.wait = wait

        var pointsSelector = Qdrant_PointsSelector()
        var idsSelector = Qdrant_PointsIdsList()
        idsSelector.ids = ids.map { $0.grpc }
        pointsSelector.points = idsSelector
        grpcRequest.pointsSelector = pointsSelector

        var vectorsSelector = Qdrant_VectorsSelector()
        vectorsSelector.names = vectorNames
        grpcRequest.vectors = vectorsSelector

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.deleteVectors(
                request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Delete vectors failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }
}
