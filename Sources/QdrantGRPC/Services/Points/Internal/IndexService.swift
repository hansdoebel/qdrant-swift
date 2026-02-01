import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Internal service for field index and facet operations.
internal final class IndexService: Sendable {
    private let base: PointsServiceBase

    init(base: PointsServiceBase) {
        self.base = base
    }

    /// Creates an index on a payload field.
    func createFieldIndex(
        collection: String,
        fieldName: String,
        fieldType: FieldType,
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_CreateFieldIndexCollection()
        grpcRequest.collectionName = collection
        grpcRequest.fieldName = fieldName
        grpcRequest.fieldType = fieldType.grpc
        grpcRequest.wait = wait

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.createFieldIndex(
                request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Create field index failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Deletes an index on a payload field.
    func deleteFieldIndex(
        collection: String,
        fieldName: String,
        wait: Bool
    ) async throws {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_DeleteFieldIndexCollection()
        grpcRequest.collectionName = collection
        grpcRequest.fieldName = fieldName
        grpcRequest.wait = wait

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_PointsOperationResponse = try await client.deleteFieldIndex(
                request: request)
            guard response.result.status == .completed || response.result.status == .acknowledged
            else {
                throw QdrantError.unexpectedResponse(
                    "Delete field index failed with status: \(response.result.status)")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Performs faceted search to get value counts.
    func facet(
        collection: String,
        key: String,
        filter: Filter?,
        limit: UInt64,
        exact: Bool
    ) async throws -> FacetResult {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_FacetCounts()
        grpcRequest.collectionName = collection
        grpcRequest.key = key
        grpcRequest.limit = limit
        grpcRequest.exact = exact

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_FacetResponse = try await client.facet(request: request)
            return FacetResult(grpc: response)
        } catch {
            throw QdrantError.from(error)
        }
    }
}
