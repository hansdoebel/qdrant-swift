import QdrantCore
import QdrantProto

/// A search request for batch search operations.
public struct SearchRequest: Sendable {
    public let vector: [Float]
    public let limit: UInt64
    public let filter: Filter?
    public let scoreThreshold: Float?
    public let withPayload: Bool

    public init(
        vector: [Float],
        limit: UInt64 = 10,
        filter: Filter? = nil,
        scoreThreshold: Float? = nil,
        withPayload: Bool = true
    ) {
        self.vector = vector
        self.limit = limit
        self.filter = filter
        self.scoreThreshold = scoreThreshold
        self.withPayload = withPayload
    }
}

/// A discover request for batch discover operations.
public struct DiscoverRequest: Sendable {
    public let target: DiscoverTarget
    public let context: [ContextPair]
    public let limit: UInt64
    public let filter: Filter?
    public let withPayload: Bool

    public init(
        target: DiscoverTarget,
        context: [ContextPair],
        limit: UInt64 = 10,
        filter: Filter? = nil,
        withPayload: Bool = true
    ) {
        self.target = target
        self.context = context
        self.limit = limit
        self.filter = filter
        self.withPayload = withPayload
    }
}

/// A recommend request for batch recommend operations.
public struct RecommendRequest: Sendable {
    public let positive: [PointID]
    public let negative: [PointID]
    public let limit: UInt64
    public let filter: Filter?
    public let withPayload: Bool

    public init(
        positive: [PointID],
        negative: [PointID] = [],
        limit: UInt64 = 10,
        filter: Filter? = nil,
        withPayload: Bool = true
    ) {
        self.positive = positive
        self.negative = negative
        self.limit = limit
        self.filter = filter
        self.withPayload = withPayload
    }
}

/// Target for discover operations.
public enum DiscoverTarget: Sendable {
    case vector([Float])
    case pointId(PointID)
}

/// A context pair for discover operations (positive and negative examples).
public struct ContextPair: Sendable {
    public let positive: DiscoverTarget
    public let negative: DiscoverTarget

    public init(positive: DiscoverTarget, negative: DiscoverTarget) {
        self.positive = positive
        self.negative = negative
    }
}


/// Result of a facet operation.
public struct FacetResult: Sendable {
    public let hits: [FacetHit]

    internal init(grpc: Qdrant_FacetResponse) {
        self.hits = grpc.hits.map { FacetHit(grpc: $0) }
    }
}

/// A single facet hit with value and count.
public struct FacetHit: Sendable {
    public let value: FacetValue
    public let count: UInt64

    internal init(grpc: Qdrant_FacetHit) {
        self.value = FacetValue(grpc: grpc.value)
        self.count = grpc.count
    }
}

/// A facet value.
public enum FacetValue: Sendable {
    case string(String)
    case integer(Int64)
    case bool(Bool)

    internal init(grpc: Qdrant_FacetValue) {
        self =
            switch grpc.variant {
            case .stringValue(let s): .string(s)
            case .integerValue(let i): .integer(i)
            case .boolValue(let b): .bool(b)
            case .none: .string("")
            }
    }
}

/// A pair of points with similarity score from matrix search.
public struct SearchMatrixPair: Sendable {
    public let a: PointID
    public let b: PointID
    public let score: Float

    internal init(grpc: Qdrant_SearchMatrixPair) {
        self.a = PointID(grpc: grpc.a) ?? .integer(0)
        self.b = PointID(grpc: grpc.b) ?? .integer(0)
        self.score = grpc.score
    }
}

/// Result of matrix search in pairs format.
public struct SearchMatrixPairsResult: Sendable {
    public let pairs: [SearchMatrixPair]

    internal init(grpc: Qdrant_SearchMatrixPairsResponse) {
        self.pairs = grpc.result.pairs.map { SearchMatrixPair(grpc: $0) }
    }
}

/// Result of matrix search in offsets format.
public struct SearchMatrixOffsetsResult: Sendable {
    public let offsetsRow: [UInt64]
    public let offsetsCol: [UInt64]
    public let scores: [Float]
    public let ids: [PointID]

    internal init(grpc: Qdrant_SearchMatrixOffsetsResponse) {
        self.offsetsRow = grpc.result.offsetsRow
        self.offsetsCol = grpc.result.offsetsCol
        self.scores = grpc.result.scores
        self.ids = grpc.result.ids.compactMap { PointID(grpc: $0) }
    }
}

/// An operation for batch updates.
public enum PointsUpdateOperation: Sendable {
    case upsert([Point])
    case deletePoints([PointID])
    case deleteByFilter(Filter)
    case setPayload(ids: [PointID], payload: [String: PayloadValue])
    case overwritePayload(ids: [PointID], payload: [String: PayloadValue])
    case deletePayload(ids: [PointID], keys: [String])
    case clearPayload(ids: [PointID])
    case updateVectors([(id: PointID, vector: VectorData)])
    case deleteVectors(ids: [PointID], vectorNames: [String])

    internal var grpc: Qdrant_PointsUpdateOperation {
        var op = Qdrant_PointsUpdateOperation()
        switch self {
        case .upsert(let points):
            var list = Qdrant_PointsUpdateOperation.PointStructList()
            list.points = points.map { $0.grpc }
            op.upsert = list
        case .deletePoints(let ids):
            var deleteOp = Qdrant_PointsUpdateOperation.DeletePoints()
            var selector = Qdrant_PointsSelector()
            var idsList = Qdrant_PointsIdsList()
            idsList.ids = ids.map { $0.grpc }
            selector.points = idsList
            deleteOp.points = selector
            op.deletePoints = deleteOp
        case .deleteByFilter(let filter):
            var deleteOp = Qdrant_PointsUpdateOperation.DeletePoints()
            var selector = Qdrant_PointsSelector()
            selector.filter = filter.grpc
            deleteOp.points = selector
            op.deletePoints = deleteOp
        case .setPayload(let ids, let payload):
            var setOp = Qdrant_PointsUpdateOperation.SetPayload()
            var selector = Qdrant_PointsSelector()
            var idsList = Qdrant_PointsIdsList()
            idsList.ids = ids.map { $0.grpc }
            selector.points = idsList
            setOp.pointsSelector = selector
            for (key, value) in payload {
                setOp.payload[key] = value.grpc
            }
            op.setPayload = setOp
        case .overwritePayload(let ids, let payload):
            var overwriteOp = Qdrant_PointsUpdateOperation.OverwritePayload()
            var selector = Qdrant_PointsSelector()
            var idsList = Qdrant_PointsIdsList()
            idsList.ids = ids.map { $0.grpc }
            selector.points = idsList
            overwriteOp.pointsSelector = selector
            for (key, value) in payload {
                overwriteOp.payload[key] = value.grpc
            }
            op.overwritePayload = overwriteOp
        case .deletePayload(let ids, let keys):
            var deleteOp = Qdrant_PointsUpdateOperation.DeletePayload()
            var selector = Qdrant_PointsSelector()
            var idsList = Qdrant_PointsIdsList()
            idsList.ids = ids.map { $0.grpc }
            selector.points = idsList
            deleteOp.pointsSelector = selector
            deleteOp.keys = keys
            op.deletePayload = deleteOp
        case .clearPayload(let ids):
            var clearOp = Qdrant_PointsUpdateOperation.ClearPayload()
            var selector = Qdrant_PointsSelector()
            var idsList = Qdrant_PointsIdsList()
            idsList.ids = ids.map { $0.grpc }
            selector.points = idsList
            clearOp.points = selector
            op.clearPayload_p = clearOp
        case .updateVectors(let updates):
            var updateOp = Qdrant_PointsUpdateOperation.UpdateVectors()
            updateOp.points = updates.map { update in
                var pv = Qdrant_PointVectors()
                pv.id = update.id.grpc
                pv.vectors = update.vector.grpc
                return pv
            }
            op.updateVectors = updateOp
        case .deleteVectors(let ids, let vectorNames):
            var deleteOp = Qdrant_PointsUpdateOperation.DeleteVectors()
            var selector = Qdrant_PointsSelector()
            var idsList = Qdrant_PointsIdsList()
            idsList.ids = ids.map { $0.grpc }
            selector.points = idsList
            deleteOp.pointsSelector = selector
            var vectorsSelector = Qdrant_VectorsSelector()
            vectorsSelector.names = vectorNames
            deleteOp.vectors = vectorsSelector
            op.deleteVectors = deleteOp
        }
        return op
    }
}

/// Result of a batch update operation.
public struct BatchUpdateResult: Sendable {
    public let statuses: [UpdateStatus]

    internal init(grpc: Qdrant_UpdateBatchResponse) {
        self.statuses = grpc.result.map { UpdateStatus(grpc: $0.status) }
    }
}

/// Status of an update operation.
public enum UpdateStatus: Sendable {
    case acknowledged
    case completed
    case clockRejected
    case unknown

    internal init(grpc: Qdrant_UpdateStatus) {
        self =
            switch grpc {
            case .acknowledged: .acknowledged
            case .completed: .completed
            case .clockRejected: .clockRejected
            default: .unknown
            }
    }
}

extension FieldType {
    internal var grpc: Qdrant_FieldType {
        switch self {
        case .keyword: .keyword
        case .integer: .integer
        case .float: .float
        case .geo: .geo
        case .text: .text
        case .bool: .bool
        case .datetime: .datetime
        case .uuid: .uuid
        }
    }
}
