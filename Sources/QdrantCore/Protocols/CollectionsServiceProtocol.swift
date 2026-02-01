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

    public init(
        name: String,
        status: CollectionStatus,
        indexedVectorsCount: UInt64? = nil,
        pointsCount: UInt64? = nil,
        segmentsCount: UInt64? = nil
    ) {
        self.name = name
        self.status = status
        self.indexedVectorsCount = indexedVectorsCount
        self.pointsCount = pointsCount
        self.segmentsCount = segmentsCount
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

    public let onDisk: Bool?

    public init(size: UInt64, distance: Distance, onDisk: Bool? = nil) {
        self.size = size
        self.distance = distance
        self.onDisk = onDisk
    }

    public init(size: Int, distance: Distance, onDisk: Bool? = nil) {
        self.size = UInt64(size)
        self.distance = distance
        self.onDisk = onDisk
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

    func create(
        name: String,
        vectorSize: UInt64,
        distance: Distance,
        onDiskPayload: Bool?
    ) async throws

    func delete(name: String) async throws

    func createAlias(alias: String, collection: String) async throws

    func deleteAlias(alias: String) async throws

    func listAliases(collection: String) async throws -> [AliasDescription]

    func listAllAliases() async throws -> [AliasDescription]
}
