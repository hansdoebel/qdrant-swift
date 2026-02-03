import Foundation

public enum RESTError: Error, Sendable {
    case statusCode(Int, message: String?)
    case decodingFailed(Error)
    case encodingFailed(Error)
    case invalidURL(String)
    case networkError(Error)
    case unexpectedResponse(String)
    case collectionNotFound(String)
    case pointNotFound(String)
    case unauthenticated
    case permissionDenied
    case badRequest(String)
    case serverError(String)
    /// TLS is required for connections to remote (non-localhost) hosts
    case tlsRequiredForRemoteHost(String)
}

extension RESTError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .statusCode(let code, let message):
            if let message { "HTTP \(code): \(message)" } else { "HTTP error: \(code)" }
        case .decodingFailed(let error): "Decoding failed: \(error.localizedDescription)"
        case .encodingFailed(let error): "Encoding failed: \(error.localizedDescription)"
        case .invalidURL(let url): "Invalid URL: \(url)"
        case .networkError(let error): "Network error: \(error.localizedDescription)"
        case .unexpectedResponse(let message): "Unexpected response: \(message)"
        case .collectionNotFound(let name): "Collection not found: \(name)"
        case .pointNotFound(let id): "Point not found: \(id)"
        case .unauthenticated: "Authentication required"
        case .permissionDenied: "Permission denied"
        case .badRequest(let message): "Bad request: \(message)"
        case .serverError(let message): "Server error: \(message)"
        case .tlsRequiredForRemoteHost(let host):
            "TLS is required for remote host '\(host)'. Use useTLS: true or connect to localhost for development."
        }
    }
}
