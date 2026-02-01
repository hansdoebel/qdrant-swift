import Foundation
import QdrantCore

/// Service for managing Qdrant collections via REST API.
public final class RestCollectionsService: Sendable {
    private let client: HTTPClient

    internal init(client: HTTPClient) {
        self.client = client
    }

    /// Lists all collections.
    /// - Returns: An array of collection descriptions.
    public func list() async throws -> [CollectionDescription] {
        let response: ListCollectionsResponse = try await client.get(path: "/collections")
        return response.result?.collections ?? []
    }

    /// Gets detailed information about a collection.
    /// - Parameter name: The name of the collection.
    /// - Returns: Information about the collection.
    public func get(name: String) async throws -> CollectionInfo {
        let response: GetCollectionResponse = try await client.get(path: "/collections/\(name)")
        guard let result = response.result else {
            throw HTTPError.unexpectedResponse("No collection info returned")
        }
        return result
    }

    /// Checks if a collection exists.
    /// - Parameter name: The name of the collection.
    /// - Returns: True if the collection exists.
    public func exists(name: String) async throws -> Bool {
        let response: CollectionExistsResponse = try await client.get(
            path: "/collections/\(name)/exists")
        return response.result?.exists ?? false
    }

    /// Creates a new collection with a single vector configuration.
    /// - Parameters:
    ///   - name: The name of the collection.
    ///   - vectorSize: The dimension of vectors.
    ///   - distance: The distance metric to use.
    ///   - onDiskPayload: Whether to store payload on disk.
    public func create(
        name: String,
        vectorSize: Int,
        distance: Distance,
        onDiskPayload: Bool? = nil
    ) async throws {
        let request = CreateCollectionRequest(
            vectors: .single(VectorConfig(size: vectorSize, distance: distance)),
            onDiskPayload: onDiskPayload
        )
        let _: OperationResponse = try await client.put(path: "/collections/\(name)", body: request)
    }

    /// Creates a new collection with multiple named vector configurations.
    /// - Parameters:
    ///   - name: The name of the collection.
    ///   - vectors: Dictionary mapping vector names to their configurations.
    ///   - onDiskPayload: Whether to store payload on disk.
    public func create(
        name: String,
        vectors: [String: VectorConfig],
        onDiskPayload: Bool? = nil
    ) async throws {
        let request = CreateCollectionRequest(
            vectors: .named(vectors),
            onDiskPayload: onDiskPayload
        )
        let _: OperationResponse = try await client.put(path: "/collections/\(name)", body: request)
    }

    /// Deletes a collection.
    /// - Parameter name: The name of the collection to delete.
    public func delete(name: String) async throws {
        let _: OperationResponse = try await client.delete(path: "/collections/\(name)")
    }

    /// Creates an alias for a collection.
    /// - Parameters:
    ///   - alias: The alias name.
    ///   - collection: The collection name.
    public func createAlias(alias: String, collection: String) async throws {
        let request = ChangeAliasesRequest(actions: [
            .createAlias(CreateAliasAction(collectionName: collection, aliasName: alias))
        ])
        let _: OperationResponse = try await client.post(
            path: "/collections/aliases", body: request)
    }

    /// Deletes an alias.
    /// - Parameter alias: The alias name to delete.
    public func deleteAlias(alias: String) async throws {
        let request = ChangeAliasesRequest(actions: [
            .deleteAlias(DeleteAliasAction(aliasName: alias))
        ])
        let _: OperationResponse = try await client.post(
            path: "/collections/aliases", body: request)
    }

    /// Lists all aliases for a collection.
    /// - Parameter collection: The collection name.
    /// - Returns: An array of alias descriptions.
    public func listAliases(collection: String) async throws -> [AliasDescription] {
        let response: ListAliasesResponse = try await client.get(
            path: "/collections/\(collection)/aliases")
        return response.result?.aliases ?? []
    }

    /// Lists all aliases across all collections.
    /// - Returns: An array of alias descriptions.
    public func listAllAliases() async throws -> [AliasDescription] {
        let response: ListAliasesResponse = try await client.get(path: "/aliases")
        return response.result?.aliases ?? []
    }

    /// Updates collection parameters.
    /// - Parameters:
    ///   - name: The collection name.
    ///   - optimizersConfig: Optional optimizer configuration changes.
    ///   - params: Optional collection parameter changes.
    public func update(
        name: String,
        optimizersConfig: RestOptimizersConfigDiff? = nil,
        params: RestCollectionParamsDiff? = nil
    ) async throws {
        let request = UpdateCollectionRequest(
            optimizersConfig: optimizersConfig,
            params: params
        )
        let _: OperationResponse = try await client.patch(
            path: "/collections/\(name)",
            body: request
        )
    }

    /// Gets cluster information for a collection.
    /// - Parameter name: The collection name.
    /// - Returns: Cluster information for the collection.
    public func collectionClusterInfo(name: String) async throws -> RestCollectionClusterInfo {
        let response: CollectionClusterInfoResponse = try await client.get(
            path: "/collections/\(name)/cluster"
        )
        guard let result = response.result else {
            throw HTTPError.unexpectedResponse("No cluster info returned")
        }
        return result
    }

    /// Creates a shard key for a collection.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - shardKey: The shard key to create.
    ///   - shardsNumber: Number of shards to create.
    ///   - replicationFactor: Replication factor for the shards.
    ///   - placement: Node placement hints.
    public func createShardKey(
        collection: String,
        shardKey: RestShardKey,
        shardsNumber: Int? = nil,
        replicationFactor: Int? = nil,
        placement: [Int]? = nil
    ) async throws {
        let request = CreateShardKeyRequest(
            shardKey: shardKey,
            shardsNumber: shardsNumber,
            replicationFactor: replicationFactor,
            placement: placement
        )
        let _: OperationResponse = try await client.put(
            path: "/collections/\(collection)/shards",
            body: request
        )
    }

    /// Deletes a shard key from a collection.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - shardKey: The shard key to delete.
    public func deleteShardKey(
        collection: String,
        shardKey: RestShardKey
    ) async throws {
        let request = DeleteShardKeyRequest(shardKey: shardKey)
        let _: OperationResponse = try await client.post(
            path: "/collections/\(collection)/shards/delete",
            body: request
        )
    }

    /// Updates collection cluster setup.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - operation: The cluster operation to perform.
    public func updateCollectionClusterSetup(
        collection: String,
        operation: RestClusterOperation
    ) async throws {
        let _: OperationResponse = try await client.post(
            path: "/collections/\(collection)/cluster",
            body: operation
        )
    }
}

struct ListCollectionsResponse: Codable {
    let result: CollectionsResult?

    struct CollectionsResult: Codable {
        let collections: [CollectionDescription]
    }
}

struct GetCollectionResponse: Codable {
    let result: CollectionInfo?
}

struct CollectionExistsResponse: Codable {
    let result: ExistsResult?

    struct ExistsResult: Codable {
        let exists: Bool
    }
}

struct OperationResponse: Codable {
    let result: Bool?
    let status: String?
}

struct ListAliasesResponse: Codable {
    let result: AliasesResult?

    struct AliasesResult: Codable {
        let aliases: [AliasDescription]
    }
}

struct CreateCollectionRequest: Encodable {
    let vectors: VectorsConfig
    let onDiskPayload: Bool?
}

struct ChangeAliasesRequest: Encodable {
    let actions: [AliasAction]

    enum AliasAction: Encodable {
        case createAlias(CreateAliasAction)
        case deleteAlias(DeleteAliasAction)
        case renameAlias(RenameAliasAction)

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .createAlias(let action): try container.encode(["create_alias": action])
            case .deleteAlias(let action): try container.encode(["delete_alias": action])
            case .renameAlias(let action): try container.encode(["rename_alias": action])
            }
        }
    }
}

struct CreateAliasAction: Encodable {
    let collectionName: String
    let aliasName: String
}

struct DeleteAliasAction: Encodable {
    let aliasName: String
}

struct RenameAliasAction: Encodable {
    let oldAliasName: String
    let newAliasName: String
}

struct UpdateCollectionRequest: Encodable {
    let optimizersConfig: RestOptimizersConfigDiff?
    let params: RestCollectionParamsDiff?
}

struct CollectionClusterInfoResponse: Codable {
    let result: RestCollectionClusterInfo?
}

struct CreateShardKeyRequest: Encodable {
    let shardKey: RestShardKey
    let shardsNumber: Int?
    let replicationFactor: Int?
    let placement: [Int]?
}

struct DeleteShardKeyRequest: Encodable {
    let shardKey: RestShardKey
}
