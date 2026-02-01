import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

public typealias HealthCheckResult = QdrantCore.HealthCheckResult
public typealias SnapshotDescription = QdrantCore.SnapshotDescription
public typealias FieldType = QdrantCore.FieldType

/// A gRPC client for interacting with Qdrant vector database.
public final class QdrantGRPCClient: Sendable {
    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>
    private let configuration: QdrantConfiguration
    private let runTask: Task<Void, any Error>

    private let _collections: CollectionsService
    private let _points: PointsService
    private let _snapshots: SnapshotsService

    /// Service for managing collections.
    public var collections: CollectionsService { _collections }

    /// Service for managing points.
    public var points: PointsService { _points }

    /// Service for managing snapshots.
    public var snapshots: SnapshotsService { _snapshots }

    /// Creates a new Qdrant client with the given configuration.
    /// - Parameter configuration: The connection configuration.
    public init(configuration: QdrantConfiguration) async throws {
        self.configuration = configuration

        let transport = try HTTP2ClientTransport.Posix(
            target: .dns(host: configuration.host, port: configuration.port),
            transportSecurity: configuration.useTLS ? .tls : .plaintext
        )

        let client = GRPCClient(transport: transport)
        self.grpcClient = client

        self.runTask = Task {
            try await client.runConnections()
        }

        self._collections = CollectionsService(client: grpcClient, apiKey: configuration.apiKey)
        self._points = PointsService(client: grpcClient, apiKey: configuration.apiKey)
        self._snapshots = SnapshotsService(client: grpcClient, apiKey: configuration.apiKey)
    }

    /// Creates a new Qdrant client with the specified connection parameters.
    /// - Parameters:
    ///   - host: The hostname of the Qdrant server (default: "localhost").
    ///   - port: The gRPC port (default: 6334).
    ///   - apiKey: Optional API key for authentication.
    ///   - useTLS: Whether to use TLS (default: auto-detected based on host).
    /// - Throws: `QdrantError.tlsRequiredForRemoteHost` if TLS is explicitly disabled for a remote host.
    public convenience init(
        host: String = "localhost",
        port: Int = 6334,
        apiKey: String? = nil,
        useTLS: Bool? = nil
    ) async throws {
        let config = try QdrantConfiguration(
            host: host,
            port: port,
            apiKey: apiKey,
            useTLS: useTLS
        )
        try await self.init(configuration: config)
    }

    /// Closes the client connection.
    public func close() {
        grpcClient.beginGracefulShutdown()
        runTask.cancel()
    }

    /// Checks the health of the Qdrant server.
    /// - Returns: Health check information including version.
    public func healthCheck() async throws -> HealthCheckResult {
        let client = Qdrant_Qdrant.Client(wrapping: grpcClient)

        var metadata = Metadata()
        if let apiKey = configuration.apiKey {
            metadata.addString(apiKey, forKey: "api-key")
        }

        let request = ClientRequest(message: Qdrant_HealthCheckRequest(), metadata: metadata)
        let response: Qdrant_HealthCheckReply = try await client.healthCheck(request: request)

        return HealthCheckResult(
            title: response.title,
            version: response.version,
            commit: response.hasCommit ? response.commit : nil
        )
    }
}
