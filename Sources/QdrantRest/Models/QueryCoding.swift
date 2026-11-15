import Foundation
import QdrantCore

extension FusionType: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "rrf": self = .rrf
        case "dbsf": self = .dbsf
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown fusion \(raw)"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .rrf: try container.encode("rrf")
        case .dbsf: try container.encode("dbsf")
        }
    }
}

extension SampleType: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard raw == "random" else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown sample \(raw)"))
        }
        self = .random
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("random")
    }
}

extension OrderDirection: Codable {
    public init(from decoder: Decoder) throws {
        switch try decoder.singleValueContainer().decode(String.self) {
        case "asc": self = .ascending
        case "desc": self = .descending
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown direction"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .ascending: try container.encode("asc")
        case .descending: try container.encode("desc")
        }
    }
}

extension Bm25Params: Codable {
    enum CodingKeys: String, CodingKey { case k, b }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            k: try container.decodeIfPresent(Float.self, forKey: .k),
            b: try container.decodeIfPresent(Float.self, forKey: .b)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(k, forKey: .k)
        try container.encodeIfPresent(b, forKey: .b)
    }
}

extension Mmr: Codable {
    enum CodingKeys: String, CodingKey {
        case diversity
        case candidatesLimit = "candidates_limit"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            diversity: try container.decodeIfPresent(Float.self, forKey: .diversity),
            candidatesLimit: try container.decodeIfPresent(UInt32.self, forKey: .candidatesLimit)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(diversity, forKey: .diversity)
        try container.encodeIfPresent(candidatesLimit, forKey: .candidatesLimit)
    }
}

extension Rrf: Codable {
    enum CodingKeys: String, CodingKey { case k, weights }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            k: try container.decodeIfPresent(UInt32.self, forKey: .k),
            weights: try container.decodeIfPresent([Float].self, forKey: .weights) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(k, forKey: .k)
        if !weights.isEmpty { try container.encode(weights, forKey: .weights) }
    }
}

extension Document: Codable {
    enum CodingKeys: String, CodingKey { case text, model, options }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            text: try container.decode(String.self, forKey: .text),
            model: try container.decode(String.self, forKey: .model),
            options: try container.decodeIfPresent([String: PayloadValue].self, forKey: .options) ?? [:]
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(model, forKey: .model)
        if !options.isEmpty { try container.encode(options, forKey: .options) }
    }
}

extension QueryImage: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        self.init(
            image: try container.decode(PayloadValue.self, forKey: DynamicKey(stringValue: "image")!),
            model: try container.decode(String.self, forKey: DynamicKey(stringValue: "model")!)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(image, forKey: DynamicKey(stringValue: "image")!)
        try container.encode(model, forKey: DynamicKey(stringValue: "model")!)
        for (key, value) in options {
            try container.encode(value, forKey: DynamicKey(stringValue: key)!)
        }
    }
}

extension InferenceObject: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        self.init(
            object: try container.decode(PayloadValue.self, forKey: DynamicKey(stringValue: "object")!),
            model: try container.decode(String.self, forKey: DynamicKey(stringValue: "model")!)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(object, forKey: DynamicKey(stringValue: "object")!)
        try container.encode(model, forKey: DynamicKey(stringValue: "model")!)
        for (key, value) in options {
            try container.encode(value, forKey: DynamicKey(stringValue: key)!)
        }
    }
}

extension VectorInput: Codable {
    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if let dense = try? single.decode([Float].self) {
            self = .dense(dense)
            return
        }
        if let multi = try? single.decode([[Float]].self) {
            self = .multiDense(multi)
            return
        }
        if let id = try? single.decode(PointID.self) {
            self = .id(id)
            return
        }
        let keyed = try decoder.container(keyedBy: VectorCodingKey.self)
        if keyed.contains(.indices) || keyed.contains(.values) {
            self = .sparse(
                indices: try keyed.decode([UInt32].self, forKey: .indices),
                values: try keyed.decode([Float].self, forKey: .values)
            )
        } else if keyed.contains(.text) {
            self = .document(try Document(from: decoder))
        } else if keyed.contains(.image) {
            let image = try keyed.decode(PayloadValue.self, forKey: .image)
            let model = try keyed.decode(String.self, forKey: .model)
            self = .image(QueryImage(image: image, model: model))
        } else if keyed.contains(.object) {
            let object = try keyed.decode(PayloadValue.self, forKey: .object)
            let model = try keyed.decode(String.self, forKey: .model)
            self = .inferenceObject(InferenceObject(object: object, model: model))
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unable to decode vector"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .dense(let values):
            var container = encoder.singleValueContainer()
            try container.encode(values)
        case .id(let id):
            var container = encoder.singleValueContainer()
            try container.encode(id)
        case .multiDense(let vectors):
            var container = encoder.singleValueContainer()
            try container.encode(vectors)
        case .sparse(let indices, let values):
            var container = encoder.container(keyedBy: VectorCodingKey.self)
            try container.encode(indices, forKey: .indices)
            try container.encode(values, forKey: .values)
        case .document(let document):
            try document.encode(to: encoder)
        case .image(let image):
            try image.encode(to: encoder)
        case .inferenceObject(let object):
            try object.encode(to: encoder)
        }
    }
}

extension TextQuery: Codable {
    enum CodingKeys: String, CodingKey { case query, bm25 }

    public init(from decoder: Decoder) throws {
        if let plain = try? decoder.singleValueContainer().decode(String.self) {
            self.init(query: plain)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            query: try container.decode(String.self, forKey: .query),
            bm25: try container.decodeIfPresent(Bm25Params.self, forKey: .bm25)
        )
    }

    public func encode(to encoder: Encoder) throws {
        if bm25 == nil {
            var container = encoder.singleValueContainer()
            try container.encode(query)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(query, forKey: .query)
            try container.encodeIfPresent(bm25, forKey: .bm25)
        }
    }
}

extension FeedbackItem: Codable {
    enum CodingKeys: String, CodingKey { case example, score }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            example: try container.decode(VectorInput.self, forKey: .example),
            score: try container.decode(Float.self, forKey: .score)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(example, forKey: .example)
        try container.encode(score, forKey: .score)
    }
}

extension NaiveFeedbackStrategy: Codable {
    enum CodingKeys: String, CodingKey { case a, b, c }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            a: try container.decode(Float.self, forKey: .a),
            b: try container.decode(Float.self, forKey: .b),
            c: try container.decode(Float.self, forKey: .c)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(a, forKey: .a)
        try container.encode(b, forKey: .b)
        try container.encode(c, forKey: .c)
    }
}

extension RelevanceFeedback: Codable {
    enum CodingKeys: String, CodingKey { case target, feedback, strategy }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let strategyContainer = try container.nestedContainer(keyedBy: StrategyKey.self, forKey: .strategy)
        self.init(
            target: try container.decode(VectorInput.self, forKey: .target),
            feedback: try container.decode([FeedbackItem].self, forKey: .feedback),
            strategy: try strategyContainer.decode(NaiveFeedbackStrategy.self, forKey: .naive)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(target, forKey: .target)
        try container.encode(feedback, forKey: .feedback)
        var strategyContainer = container.nestedContainer(keyedBy: StrategyKey.self, forKey: .strategy)
        try strategyContainer.encode(strategy, forKey: .naive)
    }

    private enum StrategyKey: String, CodingKey { case naive }
}

extension ContextInputPair: Codable {
    enum CodingKeys: String, CodingKey { case positive, negative }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            positive: try container.decode(VectorInput.self, forKey: .positive),
            negative: try container.decode(VectorInput.self, forKey: .negative)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(positive, forKey: .positive)
        try container.encode(negative, forKey: .negative)
    }
}

extension DecayParams: Codable {
    enum CodingKeys: String, CodingKey { case x, target, scale, midpoint }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            x: try container.decode(QdrantCore.Expression.self, forKey: .x),
            target: try container.decodeIfPresent(QdrantCore.Expression.self, forKey: .target),
            scale: try container.decodeIfPresent(Float.self, forKey: .scale),
            midpoint: try container.decodeIfPresent(Float.self, forKey: .midpoint)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encodeIfPresent(scale, forKey: .scale)
        try container.encodeIfPresent(midpoint, forKey: .midpoint)
    }
}

extension QdrantCore.Expression: Codable {
    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if let number = try? single.decode(Float.self) {
            self = .constant(number)
            return
        }
        if let name = try? single.decode(String.self) {
            self = .variable(name)
            return
        }
        let keyed = try decoder.container(keyedBy: ExpressionKey.self)
        if let value = try keyed.decodeIfPresent(QdrantCore.Expression.self, forKey: .acosh) {
            self = .acosh(value)
        } else if let value = try keyed.decodeIfPresent([QdrantCore.Expression].self, forKey: .max) {
            self = .max(value)
        } else if let value = try keyed.decodeIfPresent([QdrantCore.Expression].self, forKey: .min) {
            self = .min(value)
        } else if let value = try keyed.decodeIfPresent([QdrantCore.Expression].self, forKey: .sum) {
            self = .sum(value)
        } else if let value = try keyed.decodeIfPresent([QdrantCore.Expression].self, forKey: .mult) {
            self = .mult(value)
        } else if keyed.contains(.geoDistance) {
            let geo = try keyed.nestedContainer(keyedBy: GeoKey.self, forKey: .geoDistance)
            let origin = try geo.decode(GeoPointJSON.self, forKey: .origin)
            self = .geoDistance(
                origin: GeoPoint(lat: origin.lat, lon: origin.lon),
                to: try geo.decode(String.self, forKey: .to)
            )
        } else if let value = try keyed.decodeIfPresent(String.self, forKey: .datetime) {
            self = .datetime(value)
        } else if let value = try keyed.decodeIfPresent(String.self, forKey: .datetimeKey) {
            self = .datetimeKey(value)
        } else if keyed.contains(.div) {
            let div = try keyed.nestedContainer(keyedBy: DivKey.self, forKey: .div)
            self = .div(
                left: try div.decode(QdrantCore.Expression.self, forKey: .left),
                right: try div.decode(QdrantCore.Expression.self, forKey: .right),
                byZeroDefault: try div.decodeIfPresent(Float.self, forKey: .byZeroDefault)
            )
        } else {
            self = .condition(try Condition(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .constant(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .variable(let name):
            var container = encoder.singleValueContainer()
            try container.encode(name)
        case .condition(let condition):
            try condition.encode(to: encoder)
        case .geoDistance(let origin, let field):
            var container = encoder.container(keyedBy: ExpressionKey.self)
            var geo = container.nestedContainer(keyedBy: GeoKey.self, forKey: .geoDistance)
            try geo.encode(GeoPointJSON(lat: origin.lat, lon: origin.lon), forKey: .origin)
            try geo.encode(field, forKey: .to)
        case .datetime(let value):
            var container = encoder.container(keyedBy: ExpressionKey.self)
            try container.encode(value, forKey: .datetime)
        case .datetimeKey(let key):
            var container = encoder.container(keyedBy: ExpressionKey.self)
            try container.encode(key, forKey: .datetimeKey)
        case .mult(let terms):
            try encodeList(terms, key: .mult, to: encoder)
        case .sum(let terms):
            try encodeList(terms, key: .sum, to: encoder)
        case .max(let terms):
            try encodeList(terms, key: .max, to: encoder)
        case .min(let terms):
            try encodeList(terms, key: .min, to: encoder)
        case .div(let left, let right, let byZeroDefault):
            var container = encoder.container(keyedBy: ExpressionKey.self)
            var div = container.nestedContainer(keyedBy: DivKey.self, forKey: .div)
            try div.encode(left, forKey: .left)
            try div.encode(right, forKey: .right)
            try div.encodeIfPresent(byZeroDefault, forKey: .byZeroDefault)
        case .neg(let value):
            try encodeUnary(value, key: .neg, to: encoder)
        case .abs(let value):
            try encodeUnary(value, key: .abs, to: encoder)
        case .sqrt(let value):
            try encodeUnary(value, key: .sqrt, to: encoder)
        case .exp(let value):
            try encodeUnary(value, key: .exp, to: encoder)
        case .log10(let value):
            try encodeUnary(value, key: .log10, to: encoder)
        case .ln(let value):
            try encodeUnary(value, key: .ln, to: encoder)
        case .acosh(let value):
            try encodeUnary(value, key: .acosh, to: encoder)
        case .expDecay(let params):
            try encodeDecay(params, key: .expDecay, to: encoder)
        case .gaussDecay(let params):
            try encodeDecay(params, key: .gaussDecay, to: encoder)
        case .linDecay(let params):
            try encodeDecay(params, key: .linDecay, to: encoder)
        case .pow(let base, let exponent):
            var container = encoder.container(keyedBy: ExpressionKey.self)
            var pow = container.nestedContainer(keyedBy: PowKey.self, forKey: .pow)
            try pow.encode(base, forKey: .base)
            try pow.encode(exponent, forKey: .exponent)
        }
    }

    private func encodeList(_ terms: [QdrantCore.Expression], key: ExpressionKey, to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ExpressionKey.self)
        try container.encode(terms, forKey: key)
    }

    private func encodeUnary(_ value: QdrantCore.Expression, key: ExpressionKey, to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ExpressionKey.self)
        try container.encode(value, forKey: key)
    }

    private func encodeDecay(_ params: DecayParams, key: ExpressionKey, to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ExpressionKey.self)
        try container.encode(params, forKey: key)
    }
}

extension Formula: Codable {
    enum CodingKeys: String, CodingKey { case formula, defaults }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            expression: try container.decode(QdrantCore.Expression.self, forKey: .formula),
            defaults: try container.decodeIfPresent([String: PayloadValue].self, forKey: .defaults) ?? [:]
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(expression, forKey: .formula)
        if !defaults.isEmpty { try container.encode(defaults, forKey: .defaults) }
    }
}

extension QueryInput: Codable {
    enum CodingKeys: String, CodingKey {
        case nearest, mmr, recommend, discover, orderBy = "order_by"
        case fusion, rrf, sample, formula
        case relevanceFeedback = "relevance_feedback"
        case text
    }

    public init(from decoder: Decoder) throws {
        if let vector = try? VectorInput(from: decoder), !decoder.looksLikeKeyedQuery {
            switch vector {
            case .id(let id): self = .nearestId(id)
            default: self = .nearest(vector)
            }
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.mmr) {
            self = .nearestWithMmr(
                nearest: try container.decode(VectorInput.self, forKey: .nearest),
                mmr: try container.decode(Mmr.self, forKey: .mmr)
            )
        } else if let fusion = try container.decodeIfPresent(FusionType.self, forKey: .fusion) {
            self = .fusion(fusion)
        } else if let rrf = try container.decodeIfPresent(Rrf.self, forKey: .rrf) {
            self = .rrf(rrf)
        } else if container.contains(.formula) {
            self = .formula(try Formula(from: decoder))
        } else if container.contains(.text) {
            if let plain = try? container.decode(String.self, forKey: .text) {
                self = .text(TextQuery(query: plain))
            } else {
                self = .text(try container.decode(TextQuery.self, forKey: .text))
            }
        } else if let feedback = try container.decodeIfPresent(
            RelevanceFeedback.self, forKey: .relevanceFeedback)
        {
            self = .relevanceFeedback(feedback)
        } else if let sample = try container.decodeIfPresent(SampleType.self, forKey: .sample) {
            self = .sample(sample)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unable to decode query"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .nearest(let vector):
            try vector.encode(to: encoder)
        case .nearestId(let id):
            var container = encoder.singleValueContainer()
            try container.encode(id)
        case .nearestWithMmr(let nearest, let mmr):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(nearest, forKey: .nearest)
            try container.encode(mmr, forKey: .mmr)
        case .recommend(let positive, let negative):
            var container = encoder.container(keyedBy: CodingKeys.self)
            var recommend = container.nestedContainer(keyedBy: RecommendKey.self, forKey: .recommend)
            try recommend.encode(positive, forKey: .positive)
            if !negative.isEmpty { try recommend.encode(negative, forKey: .negative) }
        case .discover(let target, let context):
            var container = encoder.container(keyedBy: CodingKeys.self)
            var discover = container.nestedContainer(keyedBy: DiscoverKey.self, forKey: .discover)
            try discover.encode(target, forKey: .target)
            try discover.encode(context, forKey: .context)
        case .orderBy(let field, let direction):
            var container = encoder.container(keyedBy: CodingKeys.self)
            var order = container.nestedContainer(keyedBy: OrderKey.self, forKey: .orderBy)
            try order.encode(field, forKey: .key)
            try order.encodeIfPresent(direction, forKey: .direction)
        case .fusion(let fusion):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(fusion, forKey: .fusion)
        case .rrf(let rrf):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(rrf, forKey: .rrf)
        case .formula(let formula):
            try formula.encode(to: encoder)
        case .sample(let sample):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(sample, forKey: .sample)
        case .relevanceFeedback(let feedback):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(feedback, forKey: .relevanceFeedback)
        case .text(let text):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(text, forKey: .text)
        }
    }

    private enum RecommendKey: String, CodingKey { case positive, negative }
    private enum DiscoverKey: String, CodingKey { case target, context }
    private enum OrderKey: String, CodingKey { case key, direction }
}

extension PrefetchQuery: Codable {
    enum CodingKeys: String, CodingKey {
        case prefetch, query, using, filter, limit
        case scoreThreshold = "score_threshold"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            prefetch: try container.decodeIfPresent([PrefetchQuery].self, forKey: .prefetch) ?? [],
            query: try container.decodeIfPresent(QueryInput.self, forKey: .query),
            using: try container.decodeIfPresent(String.self, forKey: .using),
            filter: try container.decodeIfPresent(Filter.self, forKey: .filter),
            scoreThreshold: try container.decodeIfPresent(Float.self, forKey: .scoreThreshold),
            limit: try container.decodeIfPresent(UInt64.self, forKey: .limit)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !prefetch.isEmpty { try container.encode(prefetch, forKey: .prefetch) }
        try container.encodeIfPresent(query, forKey: .query)
        try container.encodeIfPresent(using, forKey: .using)
        try container.encodeIfPresent(filter, forKey: .filter)
        try container.encodeIfPresent(scoreThreshold, forKey: .scoreThreshold)
        try container.encodeIfPresent(limit, forKey: .limit)
    }
}

private struct GeoPointJSON: Codable {
    var lat: Double
    var lon: Double
}

private enum VectorCodingKey: String, CodingKey {
    case indices, values, text, image, object, model
}

private enum ExpressionKey: String, CodingKey {
    case acosh, max, min, sum, mult, div, neg, abs, sqrt, pow, exp, log10, ln
    case geoDistance = "geo_distance"
    case datetime
    case datetimeKey = "datetime_key"
    case expDecay = "exp_decay"
    case gaussDecay = "gauss_decay"
    case linDecay = "lin_decay"
}

private enum GeoKey: String, CodingKey { case origin, to }
private enum DivKey: String, CodingKey {
    case left, right
    case byZeroDefault = "by_zero_default"
}
private enum PowKey: String, CodingKey { case base, exponent }

private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension Decoder {
    fileprivate var looksLikeKeyedQuery: Bool {
        (try? container(keyedBy: QueryInput.CodingKeys.self).allKeys.isEmpty == false) ?? false
    }
}
