import Foundation

public struct Filter: Sendable {
    public var must: [Condition]

    public var should: [Condition]

    public var mustNot: [Condition]

    public init(
        must: [Condition] = [],
        should: [Condition] = [],
        mustNot: [Condition] = []
    ) {
        self.must = must
        self.should = should
        self.mustNot = mustNot
    }
}

public enum Condition: Sendable {
    case field(FieldCondition)

    case isEmpty(key: String)

    case isNull(key: String)

    case hasId([PointID])

    case filter(Filter)

    public static func field(key: String, match: Match) -> Condition {
        .field(FieldCondition(key: key, match: match))
    }

    public static func field(key: String, range: Range) -> Condition {
        .field(FieldCondition(key: key, range: range))
    }

    public static func field(key: String, geo: GeoCondition) -> Condition {
        .field(FieldCondition(key: key, geo: geo))
    }
}

public struct FieldCondition: Sendable {
    public let key: String

    public let match: Match?

    public let range: Range?

    public let geo: GeoCondition?

    public init(key: String, match: Match) {
        self.key = key
        self.match = match
        self.range = nil
        self.geo = nil
    }

    public init(key: String, range: Range) {
        self.key = key
        self.match = nil
        self.range = range
        self.geo = nil
    }

    public init(key: String, geo: GeoCondition) {
        self.key = key
        self.match = nil
        self.range = nil
        self.geo = geo
    }
}

public enum Match: Sendable {
    case keyword(String)

    case integer(Int64)

    case boolean(Bool)

    case text(String)

    case anyKeyword([String])

    case anyInteger([Int64])

    case exceptKeyword([String])

    case exceptInteger([Int64])

    public static func exact(_ value: String) -> Match {
        .keyword(value)
    }

    public static func exact(_ value: Int64) -> Match {
        .integer(value)
    }

    public static func exact(_ value: Int) -> Match {
        .integer(Int64(value))
    }

    public static func exact(_ value: Bool) -> Match {
        .boolean(value)
    }

    public static func any(_ values: [String]) -> Match {
        .anyKeyword(values)
    }

    public static func any(_ values: [Int64]) -> Match {
        .anyInteger(values)
    }

    public static func any(_ values: [Int]) -> Match {
        .anyInteger(values.map { Int64($0) })
    }
}

public struct Range: Sendable {
    public var lt: Double?

    public var gt: Double?

    public var lte: Double?

    public var gte: Double?

    public init(lt: Double? = nil, gt: Double? = nil, lte: Double? = nil, gte: Double? = nil) {
        self.lt = lt
        self.gt = gt
        self.lte = lte
        self.gte = gte
    }

    public static func greaterThan(_ value: Double) -> Range {
        Range(gt: value)
    }

    public static func greaterThanOrEqual(_ value: Double) -> Range {
        Range(gte: value)
    }

    public static func lessThan(_ value: Double) -> Range {
        Range(lt: value)
    }

    public static func lessThanOrEqual(_ value: Double) -> Range {
        Range(lte: value)
    }

    public static func between(_ lower: Double, _ upper: Double) -> Range {
        Range(lte: upper, gte: lower)
    }
}

public struct GeoPoint: Sendable, Hashable {
    public let lat: Double

    public let lon: Double

    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

public enum GeoCondition: Sendable {
    case radius(center: GeoPoint, radius: Double)

    case boundingBox(topLeft: GeoPoint, bottomRight: GeoPoint)
}
