import Foundation
import QdrantCore

/// A REST client for interacting with Qdrant vector database.
public final class QdrantRESTClient: Sendable {
    private let httpClient: HTTPClient

    private let _collections: RestCollectionsService
    private let _points: RestPointsService
    private let _snapshots: RestSnapshotsService

    /// Service for managing collections.
    public var collections: RestCollectionsService { _collections }

    /// Service for managing points.
    public var points: RestPointsService { _points }

    /// Service for managing snapshots.
    public var snapshots: RestSnapshotsService { _snapshots }

    /// Creates a new Qdrant REST client.
    /// - Parameters:
    ///   - host: The hostname of the Qdrant server (default: "localhost").
    ///   - port: The REST API port (default: 6333).
    ///   - useTLS: Whether to use HTTPS (default: auto-detected based on host).
    ///   - apiKey: Optional API key for authentication.
    ///   - session: URLSession to use (default: shared session).
    /// - Throws: `HTTPError.tlsRequiredForRemoteHost` if TLS is explicitly disabled for a remote host.
    public init(
        host: String = "localhost",
        port: Int = 6333,
        useTLS: Bool? = nil,
        apiKey: String? = nil,
        session: URLSession = .shared
    ) throws {
        let isLocalhost = Self.isLocalhostAddress(host)
        let shouldUseTLS: Bool

        if let explicitTLS = useTLS {
            // User explicitly specified TLS setting
            if !explicitTLS && !isLocalhost {
                // Security: Refuse to disable TLS for remote hosts
                throw HTTPError.tlsRequiredForRemoteHost(host)
            }
            shouldUseTLS = explicitTLS
        } else {
            // Auto-detect: use TLS for non-localhost
            shouldUseTLS = !isLocalhost
        }

        self.httpClient = try HTTPClient(
            host: host,
            port: port,
            useTLS: shouldUseTLS,
            apiKey: apiKey,
            session: session
        )

        self._collections = RestCollectionsService(client: httpClient)
        self._points = RestPointsService(client: httpClient)
        self._snapshots = RestSnapshotsService(client: httpClient)
    }

    /// Checks if the given host is a localhost address.
    private static func isLocalhostAddress(_ host: String) -> Bool {
        let lowercased = host.lowercased()
        return lowercased == "localhost"
            || lowercased == "127.0.0.1"
            || lowercased == "::1"
            || lowercased == "[::1]"
    }

    /// Checks the health of the Qdrant server.
    /// - Returns: Health check information.
    public func healthCheck() async throws -> RestHealthCheckResult {
        try await httpClient.get(path: "/healthz")
    }

    /// Gets telemetry information from the server.
    /// - Returns: Telemetry data.
    public func telemetry() async throws -> TelemetryResponse {
        try await httpClient.get(path: "/telemetry")
    }

    /// Gets metrics from the server in Prometheus format.
    /// - Returns: Metrics data as a string.
    public func metrics() async throws -> String {
        try await httpClient.getText(path: "/metrics")
    }

    /// Gets known issues from the server.
    /// - Returns: Array of known issues.
    public func issues() async throws -> [QdrantIssue] {
        let response: IssuesResponse = try await httpClient.get(path: "/issues")
        return response.result?.issues ?? []
    }

    /// Clears all known issues.
    public func clearIssues() async throws {
        let _: ClearIssuesResponse = try await httpClient.delete(path: "/issues")
    }
}

struct IssuesResponse: Codable {
    let result: IssuesResult?

    struct IssuesResult: Codable {
        let issues: [QdrantIssue]
    }
}

struct ClearIssuesResponse: Codable {
    let result: Bool?
}

/// Result of a health check operation.
public struct RestHealthCheckResult: Codable, Sendable {
    /// The title of the Qdrant instance.
    public let title: String?

    /// The version of Qdrant.
    public let version: String?
}

/// Telemetry response from the server.
public struct TelemetryResponse: Codable, Sendable {
    /// The result status.
    public let result: TelemetryData?
}

/// Telemetry data.
public struct TelemetryData: Codable, Sendable {
    /// Application information.
    public let app: AppInfo?

    /// Application information.
    public struct AppInfo: Codable, Sendable {
        /// App name.
        public let name: String?

        /// App version.
        public let version: String?
    }
}
