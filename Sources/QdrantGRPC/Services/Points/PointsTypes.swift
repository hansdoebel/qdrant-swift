import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
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

/// A query request for batch query operations.
public struct QueryRequest: Sendable {
    public let query: QueryInput?
    public let prefetch: [PrefetchQuery]
    public let using: String?
    public let filter: Filter?
    public let limit: UInt64
    public let scoreThreshold: Float?
    public let withPayload: Bool

    public init(
        query: QueryInput? = nil,
        prefetch: [PrefetchQuery] = [],
        using: String? = nil,
        filter: Filter? = nil,
        limit: UInt64 = 10,
        scoreThreshold: Float? = nil,
        withPayload: Bool = true
    ) {
        self.query = query
        self.prefetch = prefetch
        self.using = using
        self.filter = filter
        self.limit = limit
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

/// A group of points from grouped search.
public struct PointGroup: Sendable {
    public let id: GroupId
    public let hits: [ScoredPoint]

    internal init(grpc: Qdrant_PointGroup) {
        self.id = GroupId(grpc: grpc.id)
        self.hits = grpc.hits.compactMap { ScoredPoint(grpc: $0) }
    }
}

/// Group identifier for grouped search results.
public enum GroupId: Sendable, Hashable {
    case unsigned(UInt64)
    case integer(Int64)
    case string(String)

    internal init(grpc: Qdrant_GroupId) {
        self =
            switch grpc.kind {
            case .unsignedValue(let value): .unsigned(value)
            case .integerValue(let value): .integer(value)
            case .stringValue(let value): .string(value)
            case .none: .string("")
            }
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

/// Input for query operations.
public enum QueryInput: Sendable {
    case nearest([Float])
    case nearestId(PointID)
    case recommend(positive: [VectorInput], negative: [VectorInput])
    case discover(target: VectorInput, context: [ContextInputPair])
    case orderBy(field: String, direction: OrderDirection?)
    case fusion(FusionType)
    case sample(SampleType)

    internal var grpc: Qdrant_Query {
        var query = Qdrant_Query()
        switch self {
        case .nearest(let vector):
            var vectorInput = Qdrant_VectorInput()
            var dense = Qdrant_DenseVector()
            dense.data = vector
            vectorInput.dense = dense
            query.nearest = vectorInput
        case .nearestId(let id):
            var vectorInput = Qdrant_VectorInput()
            vectorInput.id = id.grpc
            query.nearest = vectorInput
        case .recommend(let positive, let negative):
            var recommendInput = Qdrant_RecommendInput()
            recommendInput.positive = positive.map { $0.grpc }
            recommendInput.negative = negative.map { $0.grpc }
            query.recommend = recommendInput
        case .discover(let target, let context):
            var discoverInput = Qdrant_DiscoverInput()
            discoverInput.target = target.grpc
            var contextInput = Qdrant_ContextInput()
            contextInput.pairs = context.map { pair in
                var contextPair = Qdrant_ContextInputPair()
                contextPair.positive = pair.positive.grpc
                contextPair.negative = pair.negative.grpc
                return contextPair
            }
            discoverInput.context = contextInput
            query.discover = discoverInput
        case .orderBy(let field, let direction):
            var orderBy = Qdrant_OrderBy()
            orderBy.key = field
            if let direction = direction {
                orderBy.direction = direction.grpc
            }
            query.orderBy = orderBy
        case .fusion(let fusionType):
            query.fusion = fusionType.grpc
        case .sample(let sampleType):
            query.sample = sampleType.grpc
        }
        return query
    }
}

/// Vector input for query operations.
public enum VectorInput: Sendable {
    case dense([Float])
    case id(PointID)

    internal var grpc: Qdrant_VectorInput {
        var input = Qdrant_VectorInput()
        switch self {
        case .dense(let vector):
            var dense = Qdrant_DenseVector()
            dense.data = vector
            input.dense = dense
        case .id(let pointId):
            input.id = pointId.grpc
        }
        return input
    }
}

/// Context input pair for discover queries.
public struct ContextInputPair: Sendable {
    public let positive: VectorInput
    public let negative: VectorInput

    public init(positive: VectorInput, negative: VectorInput) {
        self.positive = positive
        self.negative = negative
    }
}

/// Order direction for ordering queries.
public enum OrderDirection: Sendable {
    case ascending
    case descending

    internal var grpc: Qdrant_Direction {
        switch self {
        case .ascending: .asc
        case .descending: .desc
        }
    }
}

/// Fusion type for combining prefetch results.
public enum FusionType: Sendable {
    case rrf

    internal var grpc: Qdrant_Fusion {
        switch self {
        case .rrf: .rrf
        }
    }
}

/// Sample type for random sampling.
public enum SampleType: Sendable {
    case random

    internal var grpc: Qdrant_Sample {
        switch self {
        case .random: .random
        }
    }
}

/// A prefetch query for multi-stage queries.
public struct PrefetchQuery: Sendable {
    public let prefetch: [PrefetchQuery]
    public let query: QueryInput?
    public let using: String?
    public let filter: Filter?
    public let scoreThreshold: Float?
    public let limit: UInt64?

    public init(
        prefetch: [PrefetchQuery] = [],
        query: QueryInput? = nil,
        using: String? = nil,
        filter: Filter? = nil,
        scoreThreshold: Float? = nil,
        limit: UInt64? = nil
    ) {
        self.prefetch = prefetch
        self.query = query
        self.using = using
        self.filter = filter
        self.scoreThreshold = scoreThreshold
        self.limit = limit
    }

    internal var grpc: Qdrant_PrefetchQuery {
        var pq = Qdrant_PrefetchQuery()
        pq.prefetch = prefetch.map { $0.grpc }
        if let query = query {
            pq.query = query.grpc
        }
        if let using = using {
            pq.using = using
        }
        if let filter = filter {
            pq.filter = filter.grpc
        }
        if let scoreThreshold = scoreThreshold {
            pq.scoreThreshold = scoreThreshold
        }
        if let limit = limit {
            pq.limit = limit
        }
        return pq
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
        }
    }
}
