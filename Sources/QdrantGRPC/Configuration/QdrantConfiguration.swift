import Foundation

public struct QdrantConfiguration: Sendable {
    public let host: String
    public let port: Int
    public let apiKey: String?
    public let useTLS: Bool
    public let timeout: Duration

    /// Creates a new Qdrant configuration.
    /// - Parameters:
    ///   - host: The hostname of the Qdrant server (default: "localhost").
    ///   - port: The gRPC port (default: 6334).
    ///   - apiKey: Optional API key for authentication.
    ///   - useTLS: Whether to use TLS (default: auto-detected based on host).
    ///   - timeout: Request timeout duration (default: 30 seconds).
    /// - Throws: `QdrantError.tlsRequiredForRemoteHost` if TLS is explicitly disabled for a remote host.
    public init(
        host: String = "localhost",
        port: Int = 6334,
        apiKey: String? = nil,
        useTLS: Bool? = nil,
        timeout: Duration = .seconds(30)
    ) throws {
        self.host = host
        self.port = port
        self.apiKey = apiKey
        self.timeout = timeout

        let isLocalhost = Self.isLocalhostAddress(host)

        if let explicitTLS = useTLS {
            // User explicitly specified TLS setting
            if !explicitTLS && !isLocalhost {
                // Security: Refuse to disable TLS for remote hosts
                throw QdrantError.tlsRequiredForRemoteHost(host)
            }
            self.useTLS = explicitTLS
        } else {
            // Auto-detect: use TLS for non-localhost
            self.useTLS = !isLocalhost
        }
    }

    /// Checks if the given host is a localhost address.
    private static func isLocalhostAddress(_ host: String) -> Bool {
        let lowercased = host.lowercased()
        return lowercased == "localhost"
            || lowercased == "127.0.0.1"
            || lowercased == "::1"
            || lowercased == "[::1]"
    }
}
