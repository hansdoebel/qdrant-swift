import Foundation

public struct Filter: Sendable {
    public var must: [Condition]

    public var should: [Condition]

    public var mustNot: [Condition]

    public var minShould: MinShould?

    public init(
        must: [Condition] = [],
        should: [Condition] = [],
        mustNot: [Condition] = [],
        minShould: MinShould? = nil
    ) {
        self.must = must
        self.should = should
        self.mustNot = mustNot
        self.minShould = minShould
    }
}

public struct MinShould: Sendable {
    public var conditions: [Condition]
    public var minCount: UInt64

    public init(conditions: [Condition], minCount: UInt64) {
        self.conditions = conditions
        self.minCount = minCount
    }
}

public enum Condition: Sendable {
    case field(FieldCondition)

    case isEmpty(key: String)

    case isNull(key: String)

    case hasId([PointID])

    case filter(Filter)

    case nested(key: String, filter: Filter)

    case hasVector(String)

    case slice(total: UInt32, index: UInt32)

    public static func field(key: String, match: Match) -> Condition {
        .field(FieldCondition(key: key, match: match))
    }

    public static func field(key: String, range: Range) -> Condition {
        .field(FieldCondition(key: key, range: range))
    }

    public static func field(key: String, geo: GeoCondition) -> Condition {
        .field(FieldCondition(key: key, geo: geo))
    }

    public static func field(key: String, valuesCount: ValuesCount) -> Condition {
        .field(FieldCondition(key: key, valuesCount: valuesCount))
    }

    public static func field(key: String, datetimeRange: DatetimeRange) -> Condition {
        .field(FieldCondition(key: key, datetimeRange: datetimeRange))
    }
}

public struct FieldCondition: Sendable {
    public let key: String

    public let match: Match?

    public let range: Range?

    public let geo: GeoCondition?

    public let valuesCount: ValuesCount?

    public let datetimeRange: DatetimeRange?

    public init(key: String, match: Match) {
        self.key = key
        self.match = match
        self.range = nil
        self.geo = nil
        self.valuesCount = nil
        self.datetimeRange = nil
    }

    public init(key: String, range: Range) {
        self.key = key
        self.match = nil
        self.range = range
        self.geo = nil
        self.valuesCount = nil
        self.datetimeRange = nil
    }

    public init(key: String, geo: GeoCondition) {
        self.key = key
        self.match = nil
        self.range = nil
        self.geo = geo
        self.valuesCount = nil
        self.datetimeRange = nil
    }

    public init(key: String, valuesCount: ValuesCount) {
        self.key = key
        self.match = nil
        self.range = nil
        self.geo = nil
        self.valuesCount = valuesCount
        self.datetimeRange = nil
    }

    public init(key: String, datetimeRange: DatetimeRange) {
        self.key = key
        self.match = nil
        self.range = nil
        self.geo = nil
        self.valuesCount = nil
        self.datetimeRange = datetimeRange
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

    case phrase(String)

    case textAny(String)

    case prefix(String)

    case substring(String)

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

public struct ValuesCount: Sendable {
    public var lt: UInt64?
    public var gt: UInt64?
    public var lte: UInt64?
    public var gte: UInt64?

    public init(lt: UInt64? = nil, gt: UInt64? = nil, lte: UInt64? = nil, gte: UInt64? = nil) {
        self.lt = lt
        self.gt = gt
        self.lte = lte
        self.gte = gte
    }
}

public struct DatetimeRange: Sendable {
    public var lt: Date?
    public var gt: Date?
    public var lte: Date?
    public var gte: Date?

    public init(lt: Date? = nil, gt: Date? = nil, lte: Date? = nil, gte: Date? = nil) {
        self.lt = lt
        self.gt = gt
        self.lte = lte
        self.gte = gte
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

public struct GeoPolygon: Sendable {
    public var exterior: [GeoPoint]
    public var interiors: [[GeoPoint]]

    public init(exterior: [GeoPoint], interiors: [[GeoPoint]] = []) {
        self.exterior = exterior
        self.interiors = interiors
    }
}

public enum GeoCondition: Sendable {
    case radius(center: GeoPoint, radius: Double)

    case boundingBox(topLeft: GeoPoint, bottomRight: GeoPoint)

    case polygon(GeoPolygon)
}
