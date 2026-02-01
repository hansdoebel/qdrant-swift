import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Internal service for discover operations.
internal final class DiscoverService: Sendable {
    private let base: PointsServiceBase

    init(base: PointsServiceBase) {
        self.base = base
    }

    /// Discovers points using context pairs (positive/negative examples).
    func discover(
        collection: String,
        target: DiscoverTarget,
        context: [ContextPair],
        limit: UInt64,
        filter: Filter?,
        withPayload: Bool
    ) async throws -> [ScoredPoint] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_DiscoverPoints()
        grpcRequest.collectionName = collection
        grpcRequest.limit = limit

        switch target {
        case .vector(let vector):
            var targetVector = Qdrant_TargetVector()
            var denseVector = Qdrant_DenseVector()
            denseVector.data = vector
            var vec = Qdrant_Vector()
            vec.dense = denseVector
            var vectorExample = Qdrant_VectorExample()
            vectorExample.vector = vec
            targetVector.single = vectorExample
            grpcRequest.target = targetVector
        case .pointId(let id):
            var targetVector = Qdrant_TargetVector()
            var vectorExample = Qdrant_VectorExample()
            vectorExample.id = id.grpc
            targetVector.single = vectorExample
            grpcRequest.target = targetVector
        }

        grpcRequest.context = context.map { pair in
            var contextPair = Qdrant_ContextExamplePair()
            switch pair.positive {
            case .vector(let vector):
                var denseVector = Qdrant_DenseVector()
                denseVector.data = vector
                var vec = Qdrant_Vector()
                vec.dense = denseVector
                var vectorExample = Qdrant_VectorExample()
                vectorExample.vector = vec
                contextPair.positive = vectorExample
            case .pointId(let id):
                var vectorExample = Qdrant_VectorExample()
                vectorExample.id = id.grpc
                contextPair.positive = vectorExample
            }
            switch pair.negative {
            case .vector(let vector):
                var denseVector = Qdrant_DenseVector()
                denseVector.data = vector
                var vec = Qdrant_Vector()
                vec.dense = denseVector
                var vectorExample = Qdrant_VectorExample()
                vectorExample.vector = vec
                contextPair.negative = vectorExample
            case .pointId(let id):
                var vectorExample = Qdrant_VectorExample()
                vectorExample.id = id.grpc
                contextPair.negative = vectorExample
            }
            return contextPair
        }

        if let filter = filter {
            grpcRequest.filter = filter.grpc
        }

        var payloadSelector = Qdrant_WithPayloadSelector()
        payloadSelector.enable = withPayload
        grpcRequest.withPayload = payloadSelector

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_DiscoverResponse = try await client.discover(request: request)
            return response.result.compactMap { ScoredPoint(grpc: $0) }
        } catch {
            throw QdrantError.from(error)
        }
    }

    /// Performs multiple discover requests in a single batch.
    func discoverBatch(
        collection: String,
        requests: [DiscoverRequest]
    ) async throws -> [[ScoredPoint]] {
        let client = Qdrant_Points.Client(wrapping: base.grpcClient)

        var grpcRequest = Qdrant_DiscoverBatchPoints()
        grpcRequest.collectionName = collection
        grpcRequest.discoverPoints = requests.map { req in
            var dp = Qdrant_DiscoverPoints()
            dp.collectionName = collection
            dp.limit = req.limit

            switch req.target {
            case .vector(let vector):
                var targetVector = Qdrant_TargetVector()
                var denseVector = Qdrant_DenseVector()
                denseVector.data = vector
                var vec = Qdrant_Vector()
                vec.dense = denseVector
                var vectorExample = Qdrant_VectorExample()
                vectorExample.vector = vec
                targetVector.single = vectorExample
                dp.target = targetVector
            case .pointId(let id):
                var targetVector = Qdrant_TargetVector()
                var vectorExample = Qdrant_VectorExample()
                vectorExample.id = id.grpc
                targetVector.single = vectorExample
                dp.target = targetVector
            }

            dp.context = req.context.map { pair in
                var contextPair = Qdrant_ContextExamplePair()
                switch pair.positive {
                case .vector(let vector):
                    var denseVector = Qdrant_DenseVector()
                    denseVector.data = vector
                    var vec = Qdrant_Vector()
                    vec.dense = denseVector
                    var vectorExample = Qdrant_VectorExample()
                    vectorExample.vector = vec
                    contextPair.positive = vectorExample
                case .pointId(let id):
                    var vectorExample = Qdrant_VectorExample()
                    vectorExample.id = id.grpc
                    contextPair.positive = vectorExample
                }
                switch pair.negative {
                case .vector(let vector):
                    var denseVector = Qdrant_DenseVector()
                    denseVector.data = vector
                    var vec = Qdrant_Vector()
                    vec.dense = denseVector
                    var vectorExample = Qdrant_VectorExample()
                    vectorExample.vector = vec
                    contextPair.negative = vectorExample
                case .pointId(let id):
                    var vectorExample = Qdrant_VectorExample()
                    vectorExample.id = id.grpc
                    contextPair.negative = vectorExample
                }
                return contextPair
            }

            if let filter = req.filter {
                dp.filter = filter.grpc
            }

            var payloadSelector = Qdrant_WithPayloadSelector()
            payloadSelector.enable = req.withPayload
            dp.withPayload = payloadSelector

            return dp
        }

        let request = ClientRequest(message: grpcRequest, metadata: base.metadata)

        do {
            let response: Qdrant_DiscoverBatchResponse = try await client.discoverBatch(
                request: request)
            return response.result.map { batchResult in
                batchResult.result.compactMap { ScoredPoint(grpc: $0) }
            }
        } catch {
            throw QdrantError.from(error)
        }
    }
}
