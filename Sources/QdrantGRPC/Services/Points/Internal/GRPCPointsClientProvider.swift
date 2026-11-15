import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Protocol providing access to the gRPC client and common metadata.
internal protocol GRPCPointsClientProvider: Sendable {
    var grpcClient: GRPCClient<HTTP2ClientTransport.Posix> { get }
    var apiKey: String? { get }
}

extension GRPCPointsClientProvider {
    var metadata: Metadata {
        var metadata = Metadata()
        if let apiKey = apiKey {
            metadata.addString(apiKey, forKey: "api-key")
        }
        return metadata
    }
}

extension Qdrant_WithPayloadSelector {
    static func enabled(_ enabled: Bool) -> Self {
        var selector = Self()
        selector.enable = enabled
        return selector
    }
}

extension Qdrant_WithVectorsSelector {
    static func enabled(_ enabled: Bool) -> Self {
        var selector = Self()
        selector.enable = enabled
        return selector
    }
}

extension Qdrant_PointsOperationResponse {
    func ensureApplied(_ action: String) throws {
        guard result.status == .completed || result.status == .acknowledged else {
            throw QdrantError.unexpectedResponse("\(action) failed with status: \(result.status)")
        }
    }
}

/// Base class for internal points services.
internal final class PointsServiceBase: GRPCPointsClientProvider, Sendable {
    let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>
    let apiKey: String?

    init(client: GRPCClient<HTTP2ClientTransport.Posix>, apiKey: String?) {
        self.grpcClient = client
        self.apiKey = apiKey
    }
}
