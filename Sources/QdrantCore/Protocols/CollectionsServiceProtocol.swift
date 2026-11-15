import Foundation

public struct CollectionDescription: Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct CollectionInfo: Sendable {
    public let name: String

    public let status: CollectionStatus

    public let indexedVectorsCount: UInt64?

    public let pointsCount: UInt64?

    public let segmentsCount: UInt64?

    public let createdAt: Date?

    public let updateQueue: UpdateQueueInfo?

    public init(
        name: String,
        status: CollectionStatus,
        indexedVectorsCount: UInt64? = nil,
        pointsCount: UInt64? = nil,
        segmentsCount: UInt64? = nil,
        createdAt: Date? = nil,
        updateQueue: UpdateQueueInfo? = nil
    ) {
        self.name = name
        self.status = status
        self.indexedVectorsCount = indexedVectorsCount
        self.pointsCount = pointsCount
        self.segmentsCount = segmentsCount
        self.createdAt = createdAt
        self.updateQueue = updateQueue
    }
}

public struct UpdateQueueInfo: Sendable {
    public var length: UInt64
    public var deferredPoints: UInt64?

    public init(length: UInt64, deferredPoints: UInt64? = nil) {
        self.length = length
        self.deferredPoints = deferredPoints
    }
}

public enum CollectionStatus: Sendable {
    case green
    case yellow
    case red
    case grey
    case unknown
}

public struct AliasDescription: Sendable {
    public let aliasName: String

    public let collectionName: String

    public init(aliasName: String, collectionName: String) {
        self.aliasName = aliasName
        self.collectionName = collectionName
    }
}

public struct VectorConfig: Sendable {
    public let size: UInt64

    public let distance: Distance

    @available(*, deprecated, message: "Use memory instead")
    public let onDisk: Bool?

    public let datatype: VectorDatatype?

    public let memory: MemoryTier?

    public init(
        size: UInt64,
        distance: Distance,
        datatype: VectorDatatype? = nil,
        memory: MemoryTier? = nil,
        onDisk: Bool? = nil
    ) {
        self.size = size
        self.distance = distance
        self.datatype = datatype
        self.memory = memory
        self.onDisk = onDisk
    }

    public init(
        size: Int,
        distance: Distance,
        datatype: VectorDatatype? = nil,
        memory: MemoryTier? = nil,
        onDisk: Bool? = nil
    ) {
        self.init(
            size: UInt64(size),
            distance: distance,
            datatype: datatype,
            memory: memory,
            onDisk: onDisk
        )
    }
}

public enum VectorsConfig: Sendable {
    case single(VectorConfig)
    case named([String: VectorConfig])
}

public protocol CollectionsServiceProtocol: Sendable {
    func list() async throws -> [CollectionDescription]

    func get(name: String) async throws -> CollectionInfo

    func exists(name: String) async throws -> Bool

    @available(*, deprecated, message: "Use create(name:options:) and payload.memory instead of onDiskPayload")
    func create(
        name: String,
        vectorSize: UInt64,
        distance: Distance,
        onDiskPayload: Bool?
    ) async throws

    func create(name: String, options: CollectionOptions) async throws

    func delete(name: String) async throws

    func createAlias(alias: String, collection: String) async throws

    func deleteAlias(alias: String) async throws

    func listAliases(collection: String) async throws -> [AliasDescription]

    func listAllAliases() async throws -> [AliasDescription]
}
