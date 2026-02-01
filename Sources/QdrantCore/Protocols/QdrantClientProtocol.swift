import Foundation

public struct HealthCheckResult: Sendable {
    public let title: String

    public let version: String

    public let commit: String?

    public init(title: String, version: String, commit: String? = nil) {
        self.title = title
        self.version = version
        self.commit = commit
    }
}

public protocol QdrantClientProtocol: Sendable {
    associatedtype Collections: CollectionsServiceProtocol

    associatedtype Points: PointsServiceProtocol

    associatedtype Snapshots: SnapshotsServiceProtocol

    var collections: Collections { get }

    var points: Points { get }

    var snapshots: Snapshots { get }

    func healthCheck() async throws -> HealthCheckResult
}
