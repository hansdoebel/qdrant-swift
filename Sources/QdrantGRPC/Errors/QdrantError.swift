import Foundation
import GRPCCore

public enum QdrantError: Error, Sendable {
    case connectionFailed(String)
    case collectionNotFound(String)
    case pointNotFound(String)
    case collectionAlreadyExists(String)
    case invalidArgument(String)
    case unexpectedResponse(String)
    case timeout
    case unavailable(String)
    case unauthenticated(String)
    case permissionDenied(String)
    case internalError(String)
    case unknown(String)
    /// TLS is required for connections to remote (non-localhost) hosts
    case tlsRequiredForRemoteHost(String)

    public static func from(_ error: Error) -> QdrantError {
        if let rpcError = error as? RPCError {
            return from(rpcError)
        }
        return .unknown(error.localizedDescription)
    }

    public static func from(_ error: RPCError) -> QdrantError {
        let message = error.message ?? "Unknown error"

        return switch error.code {
        case .invalidArgument: .invalidArgument(message)
        case .notFound:
            if message.lowercased().contains("collection") {
                .collectionNotFound(message)
            } else if message.lowercased().contains("point") {
                .pointNotFound(message)
            } else {
                .unknown(message)
            }
        case .alreadyExists: .collectionAlreadyExists(message)
        case .deadlineExceeded: .timeout
        case .unavailable: .unavailable(message)
        case .unauthenticated: .unauthenticated(message)
        case .permissionDenied: .permissionDenied(message)
        case .internalError: .internalError(message)
        default: .unknown(message)
        }
    }
}

extension QdrantError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let message): "Connection failed: \(message)"
        case .collectionNotFound(let name): "Collection not found: \(name)"
        case .pointNotFound(let id): "Point not found: \(id)"
        case .collectionAlreadyExists(let name): "Collection already exists: \(name)"
        case .invalidArgument(let message): "Invalid argument: \(message)"
        case .unexpectedResponse(let message): "Unexpected response: \(message)"
        case .timeout: "Operation timed out"
        case .unavailable(let message): "Server unavailable: \(message)"
        case .unauthenticated(let message): "Authentication failed: \(message)"
        case .permissionDenied(let message): "Permission denied: \(message)"
        case .internalError(let message): "Internal server error: \(message)"
        case .unknown(let message): "Unknown error: \(message)"
        case .tlsRequiredForRemoteHost(let host):
            "TLS is required for remote host '\(host)'. Use useTLS: true or connect to localhost for development."
        }
    }
}
