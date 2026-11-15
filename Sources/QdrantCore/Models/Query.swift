import Foundation

/// A point id or an explicit vector used by the query API.
public enum VectorInput: Sendable {
    case dense([Float])
    case id(PointID)
    case sparse(indices: [UInt32], values: [Float])
    case multiDense([[Float]])
    case document(Document)
    case image(QueryImage)
    case inferenceObject(InferenceObject)
}

extension VectorInput: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Float...) {
        self = .dense(elements)
    }
}

/// Text passed to an inference model.
public struct Document: Sendable {
    public var text: String
    public var model: String
    public var options: [String: PayloadValue]

    public init(text: String, model: String, options: [String: PayloadValue] = [:]) {
        self.text = text
        self.model = model
        self.options = options
    }
}

/// Image passed to an inference model. `image` is a URL or base64 payload value.
public struct QueryImage: Sendable {
    public var image: PayloadValue
    public var model: String
    public var options: [String: PayloadValue]

    public init(image: PayloadValue, model: String, options: [String: PayloadValue] = [:]) {
        self.image = image
        self.model = model
        self.options = options
    }
}

/// Arbitrary object passed to an inference model.
public struct InferenceObject: Sendable {
    public var object: PayloadValue
    public var model: String
    public var options: [String: PayloadValue]

    public init(object: PayloadValue, model: String, options: [String: PayloadValue] = [:]) {
        self.object = object
        self.model = model
        self.options = options
    }
}

/// Maximal marginal relevance reranking applied to a nearest query.
public struct Mmr: Sendable {
    public var diversity: Float?
    public var candidatesLimit: UInt32?

    public init(diversity: Float? = nil, candidatesLimit: UInt32? = nil) {
        self.diversity = diversity
        self.candidatesLimit = candidatesLimit
    }
}

/// Parameterized reciprocal rank fusion.
public struct Rrf: Sendable {
    public var k: UInt32?
    public var weights: [Float]

    public init(k: UInt32? = nil, weights: [Float] = []) {
        self.k = k
        self.weights = weights
    }
}

/// Fusion of prefetch results.
public enum FusionType: Sendable {
    /// Reciprocal rank fusion with Qdrant's default parameters.
    case rrf
    /// Distribution-based score fusion.
    case dbsf
}

/// Random sample of points.
public enum SampleType: Sendable {
    case random
}

/// BM25 parameters for a text query. Defaults are `k = 1.2` and `b = 0.75` when omitted.
public struct Bm25Params: Sendable {
    public var k: Float?
    public var b: Float?

    public init(k: Float? = nil, b: Float? = nil) {
        self.k = k
        self.b = b
    }
}

/// Rank by BM25 over the text index of the payload field named by `using`.
public struct TextQuery: Sendable {
    public var query: String
    public var bm25: Bm25Params?

    public init(query: String, bm25: Bm25Params? = nil) {
        self.query = query
        self.bm25 = bm25
    }
}

/// Population over which IDF statistics are computed.
public struct IdfParams: Sendable {
    public var corpus: Filter?

    public init(corpus: Filter? = nil) {
        self.corpus = corpus
    }
}

/// One scored example supplied to relevance feedback.
public struct FeedbackItem: Sendable {
    public var example: VectorInput
    public var score: Float

    public init(example: VectorInput, score: Float) {
        self.example = example
        self.score = score
    }
}

/// Naive relevance-feedback strategy: `a * score + sim(confidence^b * c * delta)`.
public struct NaiveFeedbackStrategy: Sendable {
    public var a: Float
    public var b: Float
    public var c: Float

    public init(a: Float, b: Float, c: Float) {
        self.a = a
        self.b = b
        self.c = c
    }
}

/// Relevance feedback from an external scorer.
public struct RelevanceFeedback: Sendable {
    public var target: VectorInput
    public var feedback: [FeedbackItem]
    public var strategy: NaiveFeedbackStrategy

    public init(target: VectorInput, feedback: [FeedbackItem], strategy: NaiveFeedbackStrategy) {
        self.target = target
        self.feedback = feedback
        self.strategy = strategy
    }
}

/// Decay parameters shared by linear, exponential, and Gaussian decay.
public struct DecayParams: Sendable {
    public var x: Expression
    public var target: Expression?
    public var scale: Float?
    public var midpoint: Float?

    public init(
        x: Expression,
        target: Expression? = nil,
        scale: Float? = nil,
        midpoint: Float? = nil
    ) {
        self.x = x
        self.target = target
        self.scale = scale
        self.midpoint = midpoint
    }
}

/// Arithmetic expression used by formula rescoring.
public indirect enum Expression: Sendable {
    case constant(Float)
    case variable(String)
    case condition(Condition)
    case geoDistance(origin: GeoPoint, to: String)
    case datetime(String)
    case datetimeKey(String)
    case mult([Expression])
    case sum([Expression])
    case div(left: Expression, right: Expression, byZeroDefault: Float?)
    case neg(Expression)
    case abs(Expression)
    case sqrt(Expression)
    case pow(base: Expression, exponent: Expression)
    case exp(Expression)
    case log10(Expression)
    case ln(Expression)
    case expDecay(DecayParams)
    case gaussDecay(DecayParams)
    case linDecay(DecayParams)
    case acosh(Expression)
    case max([Expression])
    case min([Expression])
}

/// Score boosting formula plus default values for missing variables.
public struct Formula: Sendable {
    public var expression: Expression
    public var defaults: [String: PayloadValue]

    public init(expression: Expression, defaults: [String: PayloadValue] = [:]) {
        self.expression = expression
        self.defaults = defaults
    }
}

/// A positive/negative pair used by discover queries.
public struct ContextInputPair: Sendable {
    public var positive: VectorInput
    public var negative: VectorInput

    public init(positive: VectorInput, negative: VectorInput) {
        self.positive = positive
        self.negative = negative
    }
}

/// Payload ordering direction.
public enum OrderDirection: Sendable {
    case ascending
    case descending
}

/// Input for the universal query API.
public enum QueryInput: Sendable {
    case nearest(VectorInput)
    case nearestId(PointID)
    case nearestWithMmr(nearest: VectorInput, mmr: Mmr)
    case recommend(positive: [VectorInput], negative: [VectorInput])
    case discover(target: VectorInput, context: [ContextInputPair])
    case orderBy(field: String, direction: OrderDirection?)
    case fusion(FusionType)
    case rrf(Rrf)
    case formula(Formula)
    case sample(SampleType)
    case relevanceFeedback(RelevanceFeedback)
    case text(TextQuery)
}

/// A prefetch stage. Nested `prefetch` values run before this stage.
public struct PrefetchQuery: Sendable {
    public var prefetch: [PrefetchQuery]
    public var query: QueryInput?
    public var using: String?
    public var filter: Filter?
    public var scoreThreshold: Float?
    public var limit: UInt64?

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
}

/// One request inside a query batch.
public struct QueryRequest: Sendable {
    public var query: QueryInput?
    public var prefetch: [PrefetchQuery]
    public var using: String?
    public var filter: Filter?
    public var limit: UInt64
    public var scoreThreshold: Float?
    public var withPayload: Bool
    public var idf: IdfParams?

    public init(
        query: QueryInput? = nil,
        prefetch: [PrefetchQuery] = [],
        using: String? = nil,
        filter: Filter? = nil,
        limit: UInt64 = 10,
        scoreThreshold: Float? = nil,
        withPayload: Bool = true,
        idf: IdfParams? = nil
    ) {
        self.query = query
        self.prefetch = prefetch
        self.using = using
        self.filter = filter
        self.limit = limit
        self.scoreThreshold = scoreThreshold
        self.withPayload = withPayload
        self.idf = idf
    }
}

/// A group of points returned by a grouped query.
public struct PointGroup: Sendable {
    public let id: GroupId
    public let hits: [ScoredPoint]

    public init(id: GroupId, hits: [ScoredPoint]) {
        self.id = id
        self.hits = hits
    }
}

/// Identifier of a point group.
public enum GroupId: Sendable, Hashable {
    case unsigned(UInt64)
    case integer(Int64)
    case string(String)
}
