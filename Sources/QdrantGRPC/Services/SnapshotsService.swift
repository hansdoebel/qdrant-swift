import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Service for managing Qdrant snapshots.
public final class SnapshotsService: Sendable {
    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>
    private let apiKey: String?

    internal init(client: GRPCClient<HTTP2ClientTransport.Posix>, apiKey: String?) {
        self.grpcClient = client
        self.apiKey = apiKey
    }

    private var metadata: Metadata {
        var metadata = Metadata()
        if let apiKey = apiKey {
            metadata.addString(apiKey, forKey: "api-key")
        }
        return metadata
    }

    /// Creates a snapshot of a collection.
    /// - Parameter collection: The collection name.
    /// - Returns: Description of the created snapshot.
    public func create(collection: String) async throws -> SnapshotDescription {
        let client = Qdrant_Snapshots.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_CreateSnapshotRequest()
        grpcRequest.collectionName = collection

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CreateSnapshotResponse = try await client.create(request: request)
            return SnapshotDescription(grpc: response.snapshotDescription)
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Lists all snapshots of a collection.
    /// - Parameter collection: The collection name.
    /// - Returns: An array of snapshot descriptions.
    public func list(collection: String) async throws -> [SnapshotDescription] {
        let client = Qdrant_Snapshots.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_ListSnapshotsRequest()
        grpcRequest.collectionName = collection

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_ListSnapshotsResponse = try await client.list(request: request)
            return response.snapshotDescriptions.map { SnapshotDescription(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Deletes a snapshot of a collection.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - snapshot: The snapshot name to delete.
    public func delete(collection: String, snapshot: String) async throws {
        let client = Qdrant_Snapshots.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_DeleteSnapshotRequest()
        grpcRequest.collectionName = collection
        grpcRequest.snapshotName = snapshot

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let _: Qdrant_DeleteSnapshotResponse = try await client.delete(request: request)
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Creates a full snapshot of all collections.
    /// - Returns: Description of the created snapshot.
    public func createFull() async throws -> SnapshotDescription {
        let client = Qdrant_Snapshots.Client(wrapping: grpcClient)

        let grpcRequest = Qdrant_CreateFullSnapshotRequest()
        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CreateSnapshotResponse = try await client.createFull(
                request: request)
            return SnapshotDescription(grpc: response.snapshotDescription)
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Lists all full snapshots.
    /// - Returns: An array of snapshot descriptions.
    public func listFull() async throws -> [SnapshotDescription] {
        let client = Qdrant_Snapshots.Client(wrapping: grpcClient)

        let grpcRequest = Qdrant_ListFullSnapshotsRequest()
        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_ListSnapshotsResponse = try await client.listFull(request: request)
            return response.snapshotDescriptions.map { SnapshotDescription(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Deletes a full snapshot.
    /// - Parameter snapshot: The snapshot name to delete.
    public func deleteFull(snapshot: String) async throws {
        let client = Qdrant_Snapshots.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_DeleteFullSnapshotRequest()
        grpcRequest.snapshotName = snapshot

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let _: Qdrant_DeleteSnapshotResponse = try await client.deleteFull(request: request)
        } catch {
            throw QdrantError.from(error)
        }
    }
}

extension SnapshotDescription {
    internal init(grpc: Qdrant_SnapshotDescription) {
        var creationTime: Date? = nil
        if grpc.hasCreationTime {
            creationTime = Date(
                timeIntervalSince1970: TimeInterval(grpc.creationTime.seconds) + TimeInterval(
                    grpc.creationTime.nanos) / 1_000_000_000
            )
        }

        self.init(
            name: grpc.name,
            creationTime: creationTime,
            size: grpc.size,
            checksum: grpc.hasChecksum ? grpc.checksum : nil
        )
    }
}
