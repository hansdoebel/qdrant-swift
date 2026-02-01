import Foundation
import QdrantCore

// Re-export types from QdrantCore
public typealias PointID = QdrantCore.PointID
public typealias VectorData = QdrantCore.VectorData
public typealias Point = QdrantCore.Point
public typealias ScoredPoint = QdrantCore.ScoredPoint
public typealias RetrievedPoint = QdrantCore.RetrievedPoint
public typealias ScrollResult = QdrantCore.ScrollResult
public typealias PayloadValue = QdrantCore.PayloadValue
public typealias Filter = QdrantCore.Filter
public typealias Condition = QdrantCore.Condition
public typealias FieldCondition = QdrantCore.FieldCondition
public typealias Match = QdrantCore.Match
public typealias Range = QdrantCore.Range
public typealias GeoPoint = QdrantCore.GeoPoint
public typealias GeoCondition = QdrantCore.GeoCondition
public typealias Distance = QdrantCore.Distance
public typealias FieldType = QdrantCore.FieldType
public typealias VectorConfig = QdrantCore.VectorConfig
public typealias VectorsConfig = QdrantCore.VectorsConfig
public typealias CollectionDescription = QdrantCore.CollectionDescription
public typealias CollectionInfo = QdrantCore.CollectionInfo
public typealias CollectionStatus = QdrantCore.CollectionStatus
public typealias AliasDescription = QdrantCore.AliasDescription
public typealias HealthCheckResult = QdrantCore.HealthCheckResult
public typealias SnapshotDescription = QdrantCore.SnapshotDescription

extension Filter: Codable {
    enum CodingKeys: String, CodingKey {
        case must, should
        case mustNot = "must_not"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let must = try container.decodeIfPresent([Condition].self, forKey: .must) ?? []
        let should = try container.decodeIfPresent([Condition].self, forKey: .should) ?? []
        let mustNot = try container.decodeIfPresent([Condition].self, forKey: .mustNot) ?? []
        self.init(must: must, should: should, mustNot: mustNot)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !must.isEmpty { try container.encode(must, forKey: .must) }
        if !should.isEmpty { try container.encode(should, forKey: .should) }
        if !mustNot.isEmpty { try container.encode(mustNot, forKey: .mustNot) }
    }
}

extension Condition: Codable {
    enum CodingKeys: String, CodingKey {
        case key, match, range, isEmpty, isNull, hasId, filter
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let filter = try? container.decode(Filter.self, forKey: .filter) {
            self = .filter(filter)
        } else if let hasId = try? container.decode([PointID].self, forKey: .hasId) {
            self = .hasId(hasId)
        } else if let isEmpty = try? container.decode(IsEmptyCodable.self, forKey: .isEmpty) {
            self = .isEmpty(key: isEmpty.key)
        } else if let isNull = try? container.decode(IsNullCodable.self, forKey: .isNull) {
            self = .isNull(key: isNull.key)
        } else {
            self = .field(try FieldCondition(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .field(let condition):
            try condition.encode(to: encoder)
        case .isEmpty(let key):
            try container.encode(IsEmptyCodable(key: key), forKey: .isEmpty)
        case .isNull(let key):
            try container.encode(IsNullCodable(key: key), forKey: .isNull)
        case .hasId(let ids):
            try container.encode(ids, forKey: .hasId)
        case .filter(let filter):
            try container.encode(filter, forKey: .filter)
        }
    }

    private struct IsEmptyCodable: Codable {
        let key: String
    }

    private struct IsNullCodable: Codable {
        let key: String
    }
}

extension FieldCondition: Codable {
    enum CodingKeys: String, CodingKey {
        case key, match, range
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = try container.decode(String.self, forKey: .key)
        let match = try container.decodeIfPresent(Match.self, forKey: .match)
        let range = try container.decodeIfPresent(Range.self, forKey: .range)

        if let match = match {
            self.init(key: key, match: match)
        } else if let range = range {
            self.init(key: key, range: range)
        } else {
            // Default to match with empty keyword if nothing else
            self.init(key: key, match: .keyword(""))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encodeIfPresent(match, forKey: .match)
        try container.encodeIfPresent(range, forKey: .range)
    }
}

extension Match: Codable {
    enum CodingKeys: String, CodingKey {
        case value, text, any, except, keywords, integers, exceptKeywords, exceptIntegers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let text = try? container.decode(String.self, forKey: .text) {
            self = .text(text)
        } else if let any = try? container.decode([String].self, forKey: .any) {
            self = .anyKeyword(any)
        } else if let any = try? container.decode([Int64].self, forKey: .any) {
            self = .anyInteger(any)
        } else if let except = try? container.decode([String].self, forKey: .except) {
            self = .exceptKeyword(except)
        } else if let except = try? container.decode([Int64].self, forKey: .except) {
            self = .exceptInteger(except)
        } else if let value = try? container.decode(PayloadValue.self, forKey: .value) {
            // Convert PayloadValue to appropriate Match type
            self =
                switch value {
                case .string(let s): .keyword(s)
                case .integer(let i): .integer(i)
                case .bool(let b): .boolean(b)
                default: .keyword("")
                }
        } else {
            throw DecodingError.typeMismatch(
                Match.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode match condition")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .keyword(let s): try container.encode(PayloadValue.string(s), forKey: .value)
        case .integer(let i): try container.encode(PayloadValue.integer(i), forKey: .value)
        case .boolean(let b): try container.encode(PayloadValue.bool(b), forKey: .value)
        case .text(let t): try container.encode(t, forKey: .text)
        case .anyKeyword(let a): try container.encode(a, forKey: .any)
        case .anyInteger(let a): try container.encode(a, forKey: .any)
        case .exceptKeyword(let e): try container.encode(e, forKey: .except)
        case .exceptInteger(let e): try container.encode(e, forKey: .except)
        }
    }
}

extension Range: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            lt: try container.decodeIfPresent(Double.self, forKey: .lt),
            gt: try container.decodeIfPresent(Double.self, forKey: .gt),
            lte: try container.decodeIfPresent(Double.self, forKey: .lte),
            gte: try container.decodeIfPresent(Double.self, forKey: .gte)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(lt, forKey: .lt)
        try container.encodeIfPresent(gt, forKey: .gt)
        try container.encodeIfPresent(lte, forKey: .lte)
        try container.encodeIfPresent(gte, forKey: .gte)
    }

    enum CodingKeys: String, CodingKey {
        case lt, gt, lte, gte
    }
}

extension Point: Codable {
    enum CodingKeys: String, CodingKey {
        case id, vector, payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(PointID.self, forKey: .id)
        let vector = try container.decode(VectorData.self, forKey: .vector)
        let payload = try container.decodeIfPresent([String: PayloadValue].self, forKey: .payload)
        self.init(id: id, vector: vector, payload: payload)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(vector, forKey: .vector)
        try container.encodeIfPresent(payload, forKey: .payload)
    }
}

extension ScoredPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case id, score, vector, payload, version
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(PointID.self, forKey: .id)
        let score = try container.decodeIfPresent(Float.self, forKey: .score)
        let vector = try container.decodeIfPresent(VectorData.self, forKey: .vector)
        let payload = try container.decodeIfPresent([String: PayloadValue].self, forKey: .payload)
        let version = try container.decodeIfPresent(UInt64.self, forKey: .version) ?? 0
        self.init(id: id, score: score, vector: vector, payload: payload, version: version)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(score, forKey: .score)
        try container.encodeIfPresent(vector, forKey: .vector)
        try container.encodeIfPresent(payload, forKey: .payload)
        try container.encode(version, forKey: .version)
    }
}

extension RetrievedPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case id, vector, payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(PointID.self, forKey: .id)
        let vector = try container.decodeIfPresent(VectorData.self, forKey: .vector)
        let payload = try container.decodeIfPresent([String: PayloadValue].self, forKey: .payload)
        self.init(id: id, vector: vector, payload: payload)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(vector, forKey: .vector)
        try container.encodeIfPresent(payload, forKey: .payload)
    }
}

extension CollectionDescription: Codable {
    enum CodingKeys: String, CodingKey {
        case name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try container.decode(String.self, forKey: .name))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
    }
}

extension CollectionInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case status
        case indexedVectorsCount = "indexed_vectors_count"
        case pointsCount = "points_count"
        case segmentsCount = "segments_count"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let statusString = try container.decodeIfPresent(String.self, forKey: .status)
        let status: CollectionStatus =
            switch statusString?.lowercased() {
            case "green": .green
            case "yellow": .yellow
            case "red": .red
            case "grey": .grey
            default: .unknown
            }
        let indexedVectorsCount = try container.decodeIfPresent(
            UInt64.self, forKey: .indexedVectorsCount)
        let pointsCount = try container.decodeIfPresent(UInt64.self, forKey: .pointsCount)
        let segmentsCount = try container.decodeIfPresent(UInt64.self, forKey: .segmentsCount)
        self.init(
            name: "", status: status, indexedVectorsCount: indexedVectorsCount,
            pointsCount: pointsCount, segmentsCount: segmentsCount)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let statusString =
            switch status {
            case .green: "green"
            case .yellow: "yellow"
            case .red: "red"
            case .grey: "grey"
            case .unknown: "unknown"
            }
        try container.encode(statusString, forKey: .status)
        try container.encodeIfPresent(indexedVectorsCount, forKey: .indexedVectorsCount)
        try container.encodeIfPresent(pointsCount, forKey: .pointsCount)
        try container.encodeIfPresent(segmentsCount, forKey: .segmentsCount)
    }
}

extension AliasDescription: Codable {
    // Note: HTTPClient uses .convertFromSnakeCase, so we use default CodingKeys
    // The decoder automatically converts alias_name -> aliasName
    enum CodingKeys: String, CodingKey {
        case aliasName
        case collectionName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            aliasName: try container.decode(String.self, forKey: .aliasName),
            collectionName: try container.decode(String.self, forKey: .collectionName)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(aliasName, forKey: .aliasName)
        try container.encode(collectionName, forKey: .collectionName)
    }
}

extension SnapshotDescription: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case creationTime = "creation_time"
        case size, checksum
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let creationTimeString = try container.decodeIfPresent(String.self, forKey: .creationTime)
        let creationTime: Date? = nil  // Simplified - would need proper date parsing
        let size = try container.decodeIfPresent(Int64.self, forKey: .size) ?? 0
        let checksum = try container.decodeIfPresent(String.self, forKey: .checksum)
        self.init(name: name, creationTime: creationTime, size: size, checksum: checksum)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        // Skip creationTime for now - would need proper date formatting
        try container.encode(size, forKey: .size)
        try container.encodeIfPresent(checksum, forKey: .checksum)
    }
}

extension HealthCheckResult: Codable {
    enum CodingKeys: String, CodingKey {
        case title, version, commit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "",
            version: try container.decodeIfPresent(String.self, forKey: .version) ?? "",
            commit: try container.decodeIfPresent(String.self, forKey: .commit)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(commit, forKey: .commit)
    }
}

/// A query for the universal query API.
public enum RestQuery: Codable, Sendable {
    /// Find nearest neighbors to a vector.
    case nearest([Float])

    /// Find nearest neighbors to a point ID.
    case nearestId(PointID)

    /// Fusion of prefetch results.
    case fusion(RestFusion)

    enum CodingKeys: String, CodingKey {
        case nearest, fusion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let array = try? container.decode([Float].self) {
            self = .nearest(array)
        } else if let id = try? container.decode(PointID.self) {
            self = .nearestId(id)
        } else {
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            if let fusion = try? keyed.decode(RestFusion.self, forKey: .fusion) {
                self = .fusion(fusion)
            } else {
                throw DecodingError.typeMismatch(
                    RestQuery.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath, debugDescription: "Unable to decode query")
                )
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .nearest(let vector):
            var container = encoder.singleValueContainer()
            try container.encode(vector)
        case .nearestId(let id):
            var container = encoder.singleValueContainer()
            try container.encode(id)
        case .fusion(let fusion):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(fusion, forKey: .fusion)
        }
    }
}

/// Fusion type for combining results.
public enum RestFusion: String, Codable, Sendable {
    case rrf
}

/// A prefetch query for multi-stage queries.
public struct RestPrefetchQuery: Codable, Sendable {
    /// Nested prefetches.
    public let prefetch: [RestPrefetchQuery]?

    /// The query to perform.
    public let query: RestQuery?

    /// Vector name to use.
    public let using: String?

    /// Filter conditions.
    public let filter: Filter?

    /// Maximum results.
    public let limit: Int?

    public init(
        prefetch: [RestPrefetchQuery]? = nil,
        query: RestQuery? = nil,
        using: String? = nil,
        filter: Filter? = nil,
        limit: Int? = nil
    ) {
        self.prefetch = prefetch
        self.query = query
        self.using = using
        self.filter = filter
        self.limit = limit
    }
}

/// Vector query for search operations.
public enum RestVectorQuery: Encodable, Sendable {
    case unnamed([Float])
    case named(String, [Float])

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .unnamed(let vector):
            var container = encoder.singleValueContainer()
            try container.encode(vector)
        case .named(let name, let vector):
            var container = encoder.container(keyedBy: DynamicCodingKeys.self)
            try container.encode(vector, forKey: DynamicCodingKeys(stringValue: name)!)
        }
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            nil
        }
    }
}

extension VectorConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case size, distance
        case onDisk = "on_disk"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let size = try container.decode(UInt64.self, forKey: .size)
        let distance = try container.decode(Distance.self, forKey: .distance)
        let onDisk = try container.decodeIfPresent(Bool.self, forKey: .onDisk)
        self.init(size: size, distance: distance, onDisk: onDisk)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try container.encode(distance, forKey: .distance)
        try container.encodeIfPresent(onDisk, forKey: .onDisk)
    }
}

extension VectorsConfig: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(VectorConfig.self) {
            self = .single(single)
        } else if let named = try? container.decode([String: VectorConfig].self) {
            self = .named(named)
        } else {
            throw DecodingError.typeMismatch(
                VectorsConfig.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode vectors config")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let config): try container.encode(config)
        case .named(let configs): try container.encode(configs)
        }
    }
}

extension FieldType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self =
            switch rawValue.lowercased() {
            case "keyword": .keyword
            case "integer": .integer
            case "float": .float
            case "geo": .geo
            case "text": .text
            case "bool": .bool
            case "datetime": .datetime
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown field type: \(rawValue)"
                )
            }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let value =
            switch self {
            case .keyword: "keyword"
            case .integer: "integer"
            case .float: "float"
            case .geo: "geo"
            case .text: "text"
            case .bool: "bool"
            case .datetime: "datetime"
            }
        try container.encode(value)
    }
}

/// Point with vector update data.
public struct PointVectorUpdate: Codable, Sendable {
    public let id: PointID
    public let vector: VectorData

    public init(id: PointID, vector: VectorData) {
        self.id = id
        self.vector = vector
    }
}

/// A single search request in a batch.
public struct SearchBatchQuery: Codable, Sendable {
    public let vector: [Float]
    public let filter: Filter?
    public let limit: Int
    public let offset: Int?
    public let withPayload: Bool?
    public let withVector: Bool?
    public let scoreThreshold: Float?

    enum CodingKeys: String, CodingKey {
        case vector, filter, limit, offset
        case withPayload = "with_payload"
        case withVector = "with_vector"
        case scoreThreshold = "score_threshold"
    }

    public init(
        vector: [Float],
        filter: Filter? = nil,
        limit: Int = 10,
        offset: Int? = nil,
        withPayload: Bool? = nil,
        withVector: Bool? = nil,
        scoreThreshold: Float? = nil
    ) {
        self.vector = vector
        self.filter = filter
        self.limit = limit
        self.offset = offset
        self.withPayload = withPayload
        self.withVector = withVector
        self.scoreThreshold = scoreThreshold
    }
}

/// A single query request in a batch.
public struct QueryBatchQuery: Codable, Sendable {
    public let query: RestQuery?
    public let prefetch: [RestPrefetchQuery]?
    public let filter: Filter?
    public let limit: Int?
    public let offset: Int?
    public let withPayload: Bool?
    public let withVector: Bool?

    enum CodingKeys: String, CodingKey {
        case query, prefetch, filter, limit, offset
        case withPayload = "with_payload"
        case withVector = "with_vector"
    }

    public init(
        query: RestQuery? = nil,
        prefetch: [RestPrefetchQuery]? = nil,
        filter: Filter? = nil,
        limit: Int? = nil,
        offset: Int? = nil,
        withPayload: Bool? = nil,
        withVector: Bool? = nil
    ) {
        self.query = query
        self.prefetch = prefetch
        self.filter = filter
        self.limit = limit
        self.offset = offset
        self.withPayload = withPayload
        self.withVector = withVector
    }
}

/// A single recommend request in a batch.
public struct RecommendBatchQuery: Codable, Sendable {
    public let positive: [PointID]
    public let negative: [PointID]?
    public let filter: Filter?
    public let limit: Int
    public let offset: Int?
    public let withPayload: Bool?
    public let withVector: Bool?
    public let scoreThreshold: Float?

    enum CodingKeys: String, CodingKey {
        case positive, negative, filter, limit, offset
        case withPayload = "with_payload"
        case withVector = "with_vector"
        case scoreThreshold = "score_threshold"
    }

    public init(
        positive: [PointID],
        negative: [PointID]? = nil,
        filter: Filter? = nil,
        limit: Int = 10,
        offset: Int? = nil,
        withPayload: Bool? = nil,
        withVector: Bool? = nil,
        scoreThreshold: Float? = nil
    ) {
        self.positive = positive
        self.negative = negative
        self.filter = filter
        self.limit = limit
        self.offset = offset
        self.withPayload = withPayload
        self.withVector = withVector
        self.scoreThreshold = scoreThreshold
    }
}

/// Target for discover operation.
public enum RestDiscoverTarget: Codable, Sendable {
    case id(PointID)
    case vector([Float])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let id = try? container.decode(PointID.self) {
            self = .id(id)
        } else if let vector = try? container.decode([Float].self) {
            self = .vector(vector)
        } else {
            throw DecodingError.typeMismatch(
                RestDiscoverTarget.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Invalid target")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .id(let id): try container.encode(id)
        case .vector(let vector): try container.encode(vector)
        }
    }
}

/// Context pair for discover operation.
public struct RestContextPair: Codable, Sendable {
    public let positive: RestDiscoverTarget
    public let negative: RestDiscoverTarget

    public init(positive: RestDiscoverTarget, negative: RestDiscoverTarget) {
        self.positive = positive
        self.negative = negative
    }
}

/// A single discover request in a batch.
public struct DiscoverBatchQuery: Codable, Sendable {
    public let target: RestDiscoverTarget
    public let context: [RestContextPair]?
    public let filter: Filter?
    public let limit: Int
    public let offset: Int?
    public let withPayload: Bool?
    public let withVector: Bool?

    enum CodingKeys: String, CodingKey {
        case target, context, filter, limit, offset
        case withPayload = "with_payload"
        case withVector = "with_vector"
    }

    public init(
        target: RestDiscoverTarget,
        context: [RestContextPair]? = nil,
        filter: Filter? = nil,
        limit: Int = 10,
        offset: Int? = nil,
        withPayload: Bool? = nil,
        withVector: Bool? = nil
    ) {
        self.target = target
        self.context = context
        self.filter = filter
        self.limit = limit
        self.offset = offset
        self.withPayload = withPayload
        self.withVector = withVector
    }
}

/// Operation for batch updates.
public enum RestPointsUpdateOperation: Encodable, Sendable {
    case upsert(points: [Point])
    case deletePoints(ids: [PointID])
    case setPayload(ids: [PointID], payload: [String: PayloadValue])
    case overwritePayload(ids: [PointID], payload: [String: PayloadValue])
    case deletePayload(ids: [PointID], keys: [String])
    case clearPayload(ids: [PointID])

    private struct UpsertOperation: Encodable {
        let upsert: UpsertBody
        struct UpsertBody: Encodable {
            let points: [Point]
        }
    }

    private struct DeleteOperation: Encodable {
        let delete: DeleteBody
        struct DeleteBody: Encodable {
            let points: [PointID]
        }
    }

    private struct SetPayloadOperation: Encodable {
        let set_payload: SetPayloadBody
        struct SetPayloadBody: Encodable {
            let points: [PointID]
            let payload: [String: PayloadValue]
        }
    }

    private struct OverwritePayloadOperation: Encodable {
        let overwrite_payload: OverwritePayloadBody
        struct OverwritePayloadBody: Encodable {
            let points: [PointID]
            let payload: [String: PayloadValue]
        }
    }

    private struct DeletePayloadOperation: Encodable {
        let delete_payload: DeletePayloadBody
        struct DeletePayloadBody: Encodable {
            let points: [PointID]
            let keys: [String]
        }
    }

    private struct ClearPayloadOperation: Encodable {
        let clear_payload: ClearPayloadBody
        struct ClearPayloadBody: Encodable {
            let points: [PointID]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .upsert(let points):
            try container.encode(UpsertOperation(upsert: .init(points: points)))
        case .deletePoints(let ids):
            try container.encode(DeleteOperation(delete: .init(points: ids)))
        case .setPayload(let ids, let payload):
            try container.encode(
                SetPayloadOperation(set_payload: .init(points: ids, payload: payload)))
        case .overwritePayload(let ids, let payload):
            try container.encode(
                OverwritePayloadOperation(overwrite_payload: .init(points: ids, payload: payload)))
        case .deletePayload(let ids, let keys):
            try container.encode(
                DeletePayloadOperation(delete_payload: .init(points: ids, keys: keys)))
        case .clearPayload(let ids):
            try container.encode(ClearPayloadOperation(clear_payload: .init(points: ids)))
        }
    }
}

/// Result of a grouped search.
public struct RestSearchGroupsResult: Codable, Sendable {
    public let groups: [RestPointGroup]

    public init(groups: [RestPointGroup]) {
        self.groups = groups
    }
}

/// A group of points.
public struct RestPointGroup: Codable, Sendable {
    public let id: RestGroupId
    public let hits: [ScoredPoint]

    public init(id: RestGroupId, hits: [ScoredPoint]) {
        self.id = id
        self.hits = hits
    }
}

/// Group identifier.
public enum RestGroupId: Codable, Sendable {
    case string(String)
    case integer(Int64)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let i = try? container.decode(Int64.self) {
            self = .integer(i)
        } else {
            throw DecodingError.typeMismatch(
                RestGroupId.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Invalid group id")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .integer(let i): try container.encode(i)
        }
    }
}

/// Result of a facet operation.
public struct RestFacetResult: Codable, Sendable {
    public let hits: [RestFacetHit]

    public init(hits: [RestFacetHit]) {
        self.hits = hits
    }
}

/// A facet hit.
public struct RestFacetHit: Codable, Sendable {
    public let value: RestFacetValue
    public let count: Int

    public init(value: RestFacetValue, count: Int) {
        self.value = value
        self.count = count
    }
}

/// Facet value.
public enum RestFacetValue: Codable, Sendable {
    case string(String)
    case integer(Int64)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let i = try? container.decode(Int64.self) {
            self = .integer(i)
        } else {
            throw DecodingError.typeMismatch(
                RestFacetValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Invalid facet value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .integer(let i): try container.encode(i)
        }
    }
}

/// Result of search matrix pairs operation.
public struct RestSearchMatrixPairsResult: Codable, Sendable {
    public let pairs: [RestSearchMatrixPair]

    public init(pairs: [RestSearchMatrixPair]) {
        self.pairs = pairs
    }
}

/// A pair in search matrix.
public struct RestSearchMatrixPair: Codable, Sendable {
    public let a: PointID
    public let b: PointID
    public let score: Float

    public init(a: PointID, b: PointID, score: Float) {
        self.a = a
        self.b = b
        self.score = score
    }
}

/// Result of search matrix offsets operation.
public struct RestSearchMatrixOffsetsResult: Codable, Sendable {
    public let ids: [PointID]
    public let offsetsRow: [Int]
    public let offsetsCol: [Int]
    public let scores: [Float]

    public init(ids: [PointID], offsetsRow: [Int], offsetsCol: [Int], scores: [Float]) {
        self.ids = ids
        self.offsetsRow = offsetsRow
        self.offsetsCol = offsetsCol
        self.scores = scores
    }
}

/// Result of an update operation.
public struct UpdateResult: Codable, Sendable {
    public let operationId: UInt64?
    public let status: UpdateStatus

    enum CodingKeys: String, CodingKey {
        case operationId = "operation_id"
        case status
    }

    public init(operationId: UInt64? = nil, status: UpdateStatus) {
        self.operationId = operationId
        self.status = status
    }
}

/// Status of an update operation.
public enum UpdateStatus: String, Codable, Sendable {
    case acknowledged
    case completed
}

/// Optimizers configuration diff for collection update.
public struct RestOptimizersConfigDiff: Codable, Sendable {
    public let indexingThreshold: Int?
    public let memmapThreshold: Int?

    enum CodingKeys: String, CodingKey {
        case indexingThreshold = "indexing_threshold"
        case memmapThreshold = "memmap_threshold"
    }

    public init(indexingThreshold: Int? = nil, memmapThreshold: Int? = nil) {
        self.indexingThreshold = indexingThreshold
        self.memmapThreshold = memmapThreshold
    }
}

/// Collection parameters diff for update.
public struct RestCollectionParamsDiff: Codable, Sendable {
    public let replicationFactor: Int?
    public let writeConsistencyFactor: Int?

    enum CodingKeys: String, CodingKey {
        case replicationFactor = "replication_factor"
        case writeConsistencyFactor = "write_consistency_factor"
    }

    public init(replicationFactor: Int? = nil, writeConsistencyFactor: Int? = nil) {
        self.replicationFactor = replicationFactor
        self.writeConsistencyFactor = writeConsistencyFactor
    }
}

/// Shard key for distributed collections.
public enum RestShardKey: Codable, Sendable {
    case keyword(String)
    case number(Int64)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .keyword(s)
        } else if let i = try? container.decode(Int64.self) {
            self = .number(i)
        } else {
            throw DecodingError.typeMismatch(
                RestShardKey.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Invalid shard key")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .keyword(let s): try container.encode(s)
        case .number(let i): try container.encode(i)
        }
    }
}

/// Cluster information for a collection.
public struct RestCollectionClusterInfo: Codable, Sendable {
    public let peerId: Int
    public let shardCount: Int
    public let localShards: [RestLocalShardInfo]
    public let remoteShards: [RestRemoteShardInfo]

    enum CodingKeys: String, CodingKey {
        case peerId = "peer_id"
        case shardCount = "shard_count"
        case localShards = "local_shards"
        case remoteShards = "remote_shards"
    }

    public init(
        peerId: Int, shardCount: Int, localShards: [RestLocalShardInfo],
        remoteShards: [RestRemoteShardInfo]
    ) {
        self.peerId = peerId
        self.shardCount = shardCount
        self.localShards = localShards
        self.remoteShards = remoteShards
    }
}

/// Local shard information.
public struct RestLocalShardInfo: Codable, Sendable {
    public let shardId: Int
    public let pointsCount: Int
    public let state: String

    enum CodingKeys: String, CodingKey {
        case shardId = "shard_id"
        case pointsCount = "points_count"
        case state
    }

    public init(shardId: Int, pointsCount: Int, state: String) {
        self.shardId = shardId
        self.pointsCount = pointsCount
        self.state = state
    }
}

/// Remote shard information.
public struct RestRemoteShardInfo: Codable, Sendable {
    public let shardId: Int
    public let peerId: Int
    public let state: String

    enum CodingKeys: String, CodingKey {
        case shardId = "shard_id"
        case peerId = "peer_id"
        case state
    }

    public init(shardId: Int, peerId: Int, state: String) {
        self.shardId = shardId
        self.peerId = peerId
        self.state = state
    }
}

/// Shard key information.
public struct RestShardKeyInfo: Codable, Sendable {
    public let shardKey: RestShardKey?
    public let pointsCount: Int?
    public let shardsCount: Int?

    enum CodingKeys: String, CodingKey {
        case shardKey = "shard_key"
        case pointsCount = "points_count"
        case shardsCount = "shards_count"
    }

    public init(shardKey: RestShardKey? = nil, pointsCount: Int? = nil, shardsCount: Int? = nil) {
        self.shardKey = shardKey
        self.pointsCount = pointsCount
        self.shardsCount = shardsCount
    }
}

/// Operation for updating cluster setup.
public enum RestClusterOperation: Encodable, Sendable {
    case moveShard(shardId: Int, toPeerId: Int, fromPeerId: Int)
    case replicateShard(shardId: Int, toPeerId: Int, fromPeerId: Int)
    case abortTransfer(shardId: Int, toPeerId: Int, fromPeerId: Int)
    case dropReplica(shardId: Int, peerId: Int)
    case restartTransfer(shardId: Int, toPeerId: Int, fromPeerId: Int)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .moveShard(let shardId, let toPeerId, let fromPeerId):
            try container.encode([
                "move_shard": [
                    "shard_id": shardId,
                    "to_peer_id": toPeerId,
                    "from_peer_id": fromPeerId,
                ]
            ])
        case .replicateShard(let shardId, let toPeerId, let fromPeerId):
            try container.encode([
                "replicate_shard": [
                    "shard_id": shardId,
                    "to_peer_id": toPeerId,
                    "from_peer_id": fromPeerId,
                ]
            ])
        case .abortTransfer(let shardId, let toPeerId, let fromPeerId):
            try container.encode([
                "abort_transfer": [
                    "shard_id": shardId,
                    "to_peer_id": toPeerId,
                    "from_peer_id": fromPeerId,
                ]
            ])
        case .dropReplica(let shardId, let peerId):
            try container.encode([
                "drop_replica": [
                    "shard_id": shardId,
                    "peer_id": peerId,
                ]
            ])
        case .restartTransfer(let shardId, let toPeerId, let fromPeerId):
            try container.encode([
                "restart_transfer": [
                    "shard_id": shardId,
                    "to_peer_id": toPeerId,
                    "from_peer_id": fromPeerId,
                ]
            ])
        }
    }
}

/// A Qdrant issue.
public struct QdrantIssue: Codable, Sendable {
    public let code: String?
    public let description: String?
    public let solution: String?
    public let timestamp: String?

    public init(
        code: String? = nil, description: String? = nil, solution: String? = nil,
        timestamp: String? = nil
    ) {
        self.code = code
        self.description = description
        self.solution = solution
        self.timestamp = timestamp
    }
}
