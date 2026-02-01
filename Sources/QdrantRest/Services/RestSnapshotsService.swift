import Foundation
import QdrantCore

/// Service for managing Qdrant snapshots via REST API.
public final class RestSnapshotsService: Sendable {
    private let client: HTTPClient

    internal init(client: HTTPClient) {
        self.client = client
    }

    /// Lists snapshots for a collection.
    /// - Parameter collection: The collection name.
    /// - Returns: An array of snapshot descriptions.
    public func list(collection: String) async throws -> [SnapshotDescription] {
        let response: SnapshotListResponse = try await client.get(
            path: "/collections/\(collection)/snapshots"
        )
        return response.result ?? []
    }

    /// Creates a new snapshot for a collection.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - wait: Whether to wait for the operation to complete.
    /// - Returns: Information about the created snapshot.
    public func create(
        collection: String,
        wait: Bool = true
    ) async throws -> SnapshotDescription {
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let response: SnapshotResponse = try await client.post(
            path: "/collections/\(collection)/snapshots",
            body: EmptyBody(),
            queryItems: queryItems
        )
        guard let result = response.result else {
            throw HTTPError.unexpectedResponse("No snapshot info returned")
        }
        return result
    }

    /// Deletes a snapshot for a collection.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - snapshot: The name of the snapshot to delete.
    ///   - wait: Whether to wait for the operation to complete.
    public func delete(
        collection: String,
        snapshot: String,
        wait: Bool = true
    ) async throws {
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: OperationResponse = try await client.delete(
            path: "/collections/\(collection)/snapshots/\(snapshot)",
            queryItems: queryItems
        )
    }

    /// Lists full storage snapshots.
    /// - Returns: An array of snapshot descriptions.
    public func listFull() async throws -> [SnapshotDescription] {
        let response: SnapshotListResponse = try await client.get(path: "/snapshots")
        return response.result ?? []
    }

    /// Creates a full storage snapshot.
    /// - Parameter wait: Whether to wait for the operation to complete.
    /// - Returns: Information about the created snapshot.
    public func createFull(wait: Bool = true) async throws -> SnapshotDescription {
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let response: SnapshotResponse = try await client.post(
            path: "/snapshots",
            body: EmptyBody(),
            queryItems: queryItems
        )
        guard let result = response.result else {
            throw HTTPError.unexpectedResponse("No snapshot info returned")
        }
        return result
    }

    /// Deletes a full storage snapshot.
    /// - Parameters:
    ///   - snapshot: The name of the snapshot to delete.
    ///   - wait: Whether to wait for the operation to complete.
    public func deleteFull(
        snapshot: String,
        wait: Bool = true
    ) async throws {
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: OperationResponse = try await client.delete(
            path: "/snapshots/\(snapshot)",
            queryItems: queryItems
        )
    }
}

struct EmptyBody: Encodable {}

struct SnapshotListResponse: Codable {
    let result: [SnapshotDescription]?
}

struct SnapshotResponse: Codable {
    let result: SnapshotDescription?
}
