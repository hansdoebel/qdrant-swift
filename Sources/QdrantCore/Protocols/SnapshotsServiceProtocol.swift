import Foundation

public struct SnapshotDescription: Sendable {
    public let name: String

    public let creationTime: Date?

    public let size: Int64

    public let checksum: String?

    public init(name: String, creationTime: Date? = nil, size: Int64 = 0, checksum: String? = nil) {
        self.name = name
        self.creationTime = creationTime
        self.size = size
        self.checksum = checksum
    }
}

public protocol SnapshotsServiceProtocol: Sendable {
    func create(collection: String) async throws -> SnapshotDescription

    func list(collection: String) async throws -> [SnapshotDescription]

    func delete(collection: String, snapshot: String) async throws

    func createFull() async throws -> SnapshotDescription

    func listFull() async throws -> [SnapshotDescription]

    func deleteFull(snapshot: String) async throws
}
