import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Service for managing Qdrant collections.
public final class CollectionsService: Sendable {
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

    /// Lists all collections.
    /// - Returns: An array of collection descriptions.
    public func list() async throws -> [CollectionDescription] {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)
        let request = ClientRequest(message: Qdrant_ListCollectionsRequest(), metadata: metadata)

        do {
            let response: Qdrant_ListCollectionsResponse = try await client.list(request: request)
            return response.collections.map { CollectionDescription(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Gets detailed information about a collection.
    /// - Parameter name: The name of the collection.
    /// - Returns: Information about the collection.
    public func get(name: String) async throws -> CollectionInfo {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_GetCollectionInfoRequest()
        grpcRequest.collectionName = name

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_GetCollectionInfoResponse = try await client.get(request: request)
            guard response.hasResult else {
                throw QdrantError.unexpectedResponse("No collection info returned")
            }
            return CollectionInfo(name: name, grpc: response.result)
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Checks if a collection exists.
    /// - Parameter name: The name of the collection.
    /// - Returns: True if the collection exists.
    public func exists(name: String) async throws -> Bool {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_CollectionExistsRequest()
        grpcRequest.collectionName = name

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CollectionExistsResponse = try await client.collectionExists(
                request: request)
            return response.result.exists
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Creates a new collection with a single vector configuration.
    /// - Parameters:
    ///   - name: The name of the collection.
    ///   - vectorSize: The dimension of vectors.
    ///   - distance: The distance metric to use.
    ///   - onDiskPayload: Whether to store payload on disk.
    public func create(
        name: String,
        vectorSize: UInt64,
        distance: Distance,
        onDiskPayload: Bool? = nil
    ) async throws {
        let config = VectorConfig(size: vectorSize, distance: distance)
        try await create(name: name, vectors: .single(config), onDiskPayload: onDiskPayload)
    }

    /// Creates a new collection with a single vector configuration (Int size convenience).
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
        try await create(
            name: name, vectorSize: UInt64(vectorSize), distance: distance,
            onDiskPayload: onDiskPayload)
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
        try await create(name: name, vectors: .named(vectors), onDiskPayload: onDiskPayload)
    }

    /// Creates a new collection.
    /// - Parameters:
    ///   - name: The name of the collection.
    ///   - vectors: The vector configuration.
    ///   - onDiskPayload: Whether to store payload on disk.
    public func create(
        name: String,
        vectors: VectorsConfig,
        onDiskPayload: Bool? = nil
    ) async throws {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_CreateCollection()
        grpcRequest.collectionName = name
        grpcRequest.vectorsConfig = vectors.grpc

        if let onDiskPayload = onDiskPayload {
            grpcRequest.onDiskPayload = onDiskPayload
        }

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CollectionOperationResponse = try await client.create(
                request: request)
            if !response.result {
                throw QdrantError.unexpectedResponse("Collection creation failed")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Updates collection parameters.
    /// - Parameters:
    ///   - name: The name of the collection.
    ///   - replicationFactor: Number of replicas for each shard.
    ///   - writeConsistencyFactor: How many replicas should apply for success.
    ///   - onDiskPayload: Whether to store payload on disk.
    ///   - indexingThreshold: Minimum number of vectors to trigger indexing.
    public func update(
        name: String,
        replicationFactor: UInt32? = nil,
        writeConsistencyFactor: UInt32? = nil,
        onDiskPayload: Bool? = nil,
        indexingThreshold: UInt64? = nil
    ) async throws {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_UpdateCollection()
        grpcRequest.collectionName = name

        // Set collection params if any provided
        if replicationFactor != nil || writeConsistencyFactor != nil || onDiskPayload != nil {
            var params = Qdrant_CollectionParamsDiff()
            if let replicationFactor = replicationFactor {
                params.replicationFactor = replicationFactor
            }
            if let writeConsistencyFactor = writeConsistencyFactor {
                params.writeConsistencyFactor = writeConsistencyFactor
            }
            if let onDiskPayload = onDiskPayload {
                params.onDiskPayload = onDiskPayload
            }
            grpcRequest.params = params
        }

        // Set optimizer config if indexing threshold provided
        if let indexingThreshold = indexingThreshold {
            var optimizers = Qdrant_OptimizersConfigDiff()
            optimizers.indexingThreshold = indexingThreshold
            grpcRequest.optimizersConfig = optimizers
        }

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CollectionOperationResponse = try await client.update(
                request: request)
            if !response.result {
                throw QdrantError.unexpectedResponse("Collection update failed")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Deletes a collection.
    /// - Parameter name: The name of the collection to delete.
    public func delete(name: String) async throws {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_DeleteCollection()
        grpcRequest.collectionName = name

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CollectionOperationResponse = try await client.delete(
                request: request)
            if !response.result {
                throw QdrantError.unexpectedResponse("Collection deletion failed")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Creates an alias for a collection.
    /// - Parameters:
    ///   - alias: The alias name.
    ///   - collection: The collection name.
    public func createAlias(alias: String, collection: String) async throws {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var createAlias = Qdrant_CreateAlias()
        createAlias.collectionName = collection
        createAlias.aliasName = alias

        var action = Qdrant_AliasOperations()
        action.createAlias = createAlias

        var grpcRequest = Qdrant_ChangeAliases()
        grpcRequest.actions = [action]

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CollectionOperationResponse = try await client.updateAliases(
                request: request)
            if !response.result {
                throw QdrantError.unexpectedResponse("Alias creation failed")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Renames an alias.
    /// - Parameters:
    ///   - oldAlias: The current alias name.
    ///   - newAlias: The new alias name.
    public func renameAlias(oldAlias: String, newAlias: String) async throws {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var renameAlias = Qdrant_RenameAlias()
        renameAlias.oldAliasName = oldAlias
        renameAlias.newAliasName = newAlias

        var action = Qdrant_AliasOperations()
        action.renameAlias = renameAlias

        var grpcRequest = Qdrant_ChangeAliases()
        grpcRequest.actions = [action]

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CollectionOperationResponse = try await client.updateAliases(
                request: request)
            if !response.result {
                throw QdrantError.unexpectedResponse("Alias rename failed")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Deletes an alias.
    /// - Parameter alias: The alias name to delete.
    public func deleteAlias(alias: String) async throws {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var deleteAlias = Qdrant_DeleteAlias()
        deleteAlias.aliasName = alias

        var action = Qdrant_AliasOperations()
        action.deleteAlias = deleteAlias

        var grpcRequest = Qdrant_ChangeAliases()
        grpcRequest.actions = [action]

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CollectionOperationResponse = try await client.updateAliases(
                request: request)
            if !response.result {
                throw QdrantError.unexpectedResponse("Alias deletion failed")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Lists all aliases for a collection.
    /// - Parameter collection: The collection name.
    /// - Returns: An array of alias descriptions.
    public func listAliases(collection: String) async throws -> [AliasDescription] {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_ListCollectionAliasesRequest()
        grpcRequest.collectionName = collection

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_ListAliasesResponse = try await client.listCollectionAliases(
                request: request)
            return response.aliases.map { AliasDescription(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Lists all aliases across all collections.
    /// - Returns: An array of alias descriptions.
    public func listAllAliases() async throws -> [AliasDescription] {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        let grpcRequest = Qdrant_ListAliasesRequest()
        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_ListAliasesResponse = try await client.listAliases(
                request: request)
            return response.aliases.map { AliasDescription(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Gets cluster information for a collection.
    /// - Parameter name: The name of the collection.
    /// - Returns: Cluster information for the collection.
    public func collectionClusterInfo(name: String) async throws -> CollectionClusterInfo {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_CollectionClusterInfoRequest()
        grpcRequest.collectionName = name

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CollectionClusterInfoResponse =
                try await client.collectionClusterInfo(request: request)
            return CollectionClusterInfo(grpc: response)
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Creates a shard key for a collection.
    /// - Parameters:
    ///   - collection: The name of the collection.
    ///   - shardKey: The shard key to create.
    ///   - shardsNumber: Number of shards to create per shard key.
    ///   - replicationFactor: Number of replicas for each shard.
    ///   - placement: List of peer IDs allowed to create shards (empty means all peers).
    public func createShardKey(
        collection: String,
        shardKey: ShardKey,
        shardsNumber: UInt32? = nil,
        replicationFactor: UInt32? = nil,
        placement: [UInt64] = []
    ) async throws {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var createRequest = Qdrant_CreateShardKey()
        createRequest.shardKey = shardKey.grpc

        if let shardsNumber = shardsNumber {
            createRequest.shardsNumber = shardsNumber
        }

        if let replicationFactor = replicationFactor {
            createRequest.replicationFactor = replicationFactor
        }

        createRequest.placement = placement

        var grpcRequest = Qdrant_CreateShardKeyRequest()
        grpcRequest.collectionName = collection
        grpcRequest.request = createRequest

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_CreateShardKeyResponse = try await client.createShardKey(
                request: request)
            if !response.result {
                throw QdrantError.unexpectedResponse("Shard key creation failed")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Deletes a shard key from a collection.
    /// - Parameters:
    ///   - collection: The name of the collection.
    ///   - shardKey: The shard key to delete.
    public func deleteShardKey(
        collection: String,
        shardKey: ShardKey
    ) async throws {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var deleteRequest = Qdrant_DeleteShardKey()
        deleteRequest.shardKey = shardKey.grpc

        var grpcRequest = Qdrant_DeleteShardKeyRequest()
        grpcRequest.collectionName = collection
        grpcRequest.request = deleteRequest

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_DeleteShardKeyResponse = try await client.deleteShardKey(
                request: request)
            if !response.result {
                throw QdrantError.unexpectedResponse("Shard key deletion failed")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Updates collection cluster setup by performing a cluster operation.
    /// - Parameters:
    ///   - collection: The name of the collection.
    ///   - operation: The cluster operation to perform.
    public func updateCollectionClusterSetup(
        collection: String,
        operation: ClusterOperation
    ) async throws {
        let client = Qdrant_Collections.Client(wrapping: grpcClient)

        var grpcRequest = Qdrant_UpdateCollectionClusterSetupRequest()
        grpcRequest.collectionName = collection

        switch operation {
        case .moveShard(let from, let to, let shardId, let method):
            var move = Qdrant_MoveShard()
            move.shardID = shardId
            move.fromPeerID = from
            move.toPeerID = to
            if let method = method {
                move.method = method.grpc
            }
            grpcRequest.moveShard = move

        case .replicateShard(let from, let to, let shardId, let method):
            var replicate = Qdrant_ReplicateShard()
            replicate.shardID = shardId
            replicate.fromPeerID = from
            replicate.toPeerID = to
            if let method = method {
                replicate.method = method.grpc
            }
            grpcRequest.replicateShard = replicate

        case .abortTransfer(let from, let to, let shardId):
            var abort = Qdrant_AbortShardTransfer()
            abort.shardID = shardId
            abort.fromPeerID = from
            abort.toPeerID = to
            grpcRequest.abortTransfer = abort

        case .dropReplica(let peerId, let shardId):
            var drop = Qdrant_Replica()
            drop.shardID = shardId
            drop.peerID = peerId
            grpcRequest.dropReplica = drop

        case .createShardKey(let key, let shardsNumber, let replicationFactor, let placement):
            var create = Qdrant_CreateShardKey()
            create.shardKey = key.grpc
            if let shardsNumber = shardsNumber {
                create.shardsNumber = shardsNumber
            }
            if let replicationFactor = replicationFactor {
                create.replicationFactor = replicationFactor
            }
            create.placement = placement
            grpcRequest.createShardKey = create

        case .deleteShardKey(let key):
            var delete = Qdrant_DeleteShardKey()
            delete.shardKey = key.grpc
            grpcRequest.deleteShardKey = delete

        case .restartTransfer(let from, let to, let shardId, let method):
            var restart = Qdrant_RestartTransfer()
            restart.shardID = shardId
            restart.fromPeerID = from
            restart.toPeerID = to
            if let method = method {
                restart.method = method.grpc
            }
            grpcRequest.restartTransfer = restart
        }

        let request = ClientRequest(message: grpcRequest, metadata: metadata)

        do {
            let response: Qdrant_UpdateCollectionClusterSetupResponse =
                try await client.updateCollectionClusterSetup(request: request)
            if !response.result {
                throw QdrantError.unexpectedResponse("Cluster setup update failed")
            }
        } catch let error as QdrantError {
            throw error
        } catch {
            throw QdrantError.from(error)
        }
    }
}

/// Information about a collection's cluster state.
public struct CollectionClusterInfo: Sendable {
    /// ID of this peer.
    public let peerId: UInt64

    /// Total number of shards.
    public let shardCount: UInt64

    /// Local shards on this node.
    public let localShards: [LocalShardInfo]

    /// Remote shards on other nodes.
    public let remoteShards: [RemoteShardInfo]

    /// Active shard transfers.
    public let shardTransfers: [ShardTransferInfo]

    internal init(grpc: Qdrant_CollectionClusterInfoResponse) {
        self.peerId = grpc.peerID
        self.shardCount = grpc.shardCount
        self.localShards = grpc.localShards.map { LocalShardInfo(grpc: $0) }
        self.remoteShards = grpc.remoteShards.map { RemoteShardInfo(grpc: $0) }
        self.shardTransfers = grpc.shardTransfers.map { ShardTransferInfo(grpc: $0) }
    }
}

/// Information about a local shard.
public struct LocalShardInfo: Sendable {
    /// Shard ID.
    public let shardId: UInt32

    /// Number of points in the shard.
    public let pointsCount: UInt64

    /// Shard state.
    public let state: ReplicaState

    /// User-defined shard key.
    public let shardKey: ShardKey?

    internal init(grpc: Qdrant_LocalShardInfo) {
        self.shardId = grpc.shardID
        self.pointsCount = grpc.pointsCount
        self.state = ReplicaState(grpc: grpc.state)
        self.shardKey = grpc.hasShardKey ? ShardKey(grpc: grpc.shardKey) : nil
    }
}

/// Information about a remote shard.
public struct RemoteShardInfo: Sendable {
    /// Shard ID.
    public let shardId: UInt32

    /// Remote peer ID.
    public let peerId: UInt64

    /// Shard state.
    public let state: ReplicaState

    /// User-defined shard key.
    public let shardKey: ShardKey?

    internal init(grpc: Qdrant_RemoteShardInfo) {
        self.shardId = grpc.shardID
        self.peerId = grpc.peerID
        self.state = ReplicaState(grpc: grpc.state)
        self.shardKey = grpc.hasShardKey ? ShardKey(grpc: grpc.shardKey) : nil
    }
}

/// Information about a shard transfer operation.
public struct ShardTransferInfo: Sendable {
    /// Shard ID being transferred.
    public let shardId: UInt32

    /// Source peer ID.
    public let from: UInt64

    /// Destination peer ID.
    public let to: UInt64

    /// Whether this is a sync operation.
    public let sync: Bool

    internal init(grpc: Qdrant_ShardTransferInfo) {
        self.shardId = grpc.shardID
        self.from = grpc.from
        self.to = grpc.to
        self.sync = grpc.sync
    }
}

/// State of a replica.
public enum ReplicaState: Sendable {
    case active
    case dead
    case partial
    case initializing
    case listener
    case partialSnapshot
    case recovery
    case resharding
    case unknown

    internal init(grpc: Qdrant_ReplicaState) {
        switch grpc {
        case .active: self = .active
        case .dead: self = .dead
        case .partial: self = .partial
        case .initializing: self = .initializing
        case .listener: self = .listener
        case .partialSnapshot: self = .partialSnapshot
        case .recovery: self = .recovery
        case .resharding: self = .resharding
        default: self = .unknown
        }
    }
}

/// A shard key for custom sharding.
public enum ShardKey: Sendable {
    /// String shard key.
    case keyword(String)

    /// Numeric shard key.
    case number(UInt64)

    internal var grpc: Qdrant_ShardKey {
        var key = Qdrant_ShardKey()
        switch self {
        case .keyword(let s):
            key.keyword = s
        case .number(let n):
            key.number = n
        }
        return key
    }

    internal init(grpc: Qdrant_ShardKey) {
        switch grpc.key {
        case .keyword(let s):
            self = .keyword(s)
        case .number(let n):
            self = .number(n)
        case .none:
            self = .keyword("")
        }
    }
}

/// Operations for updating collection cluster setup.
public enum ClusterOperation: Sendable {
    /// Move shard from one peer to another.
    case moveShard(from: UInt64, to: UInt64, shardId: UInt32, method: ShardTransferMethod?)

    /// Replicate shard from one peer to another.
    case replicateShard(from: UInt64, to: UInt64, shardId: UInt32, method: ShardTransferMethod?)

    /// Abort shard transfer operation.
    case abortTransfer(from: UInt64, to: UInt64, shardId: UInt32)

    /// Drop replica from peer.
    case dropReplica(peerId: UInt64, shardId: UInt32)

    /// Create a new shard key.
    case createShardKey(
        key: ShardKey, shardsNumber: UInt32?, replicationFactor: UInt32?, placement: [UInt64])

    /// Delete a shard key.
    case deleteShardKey(key: ShardKey)

    /// Restart a failed shard transfer.
    case restartTransfer(from: UInt64, to: UInt64, shardId: UInt32, method: ShardTransferMethod?)
}

/// Method for shard transfer operations.
public enum ShardTransferMethod: Sendable {
    /// Stream records during transfer.
    case streamRecords

    /// Use snapshot for transfer.
    case snapshot

    /// Use write-ahead log delta for transfer.
    case walDelta

    /// Use resharding for transfer.
    case reshardingStreamRecords

    internal var grpc: Qdrant_ShardTransferMethod {
        switch self {
        case .streamRecords:
            return .streamRecords
        case .snapshot:
            return .snapshot
        case .walDelta:
            return .walDelta
        case .reshardingStreamRecords:
            return .reshardingStreamRecords
        }
    }
}
