import Foundation
import QdrantCore
import QdrantProto

public typealias Filter = QdrantCore.Filter
public typealias Condition = QdrantCore.Condition
public typealias FieldCondition = QdrantCore.FieldCondition
public typealias Match = QdrantCore.Match
public typealias Range = QdrantCore.Range
public typealias GeoPoint = QdrantCore.GeoPoint
public typealias GeoCondition = QdrantCore.GeoCondition

extension Filter {
    /// Converts to the gRPC Filter representation.
    internal var grpc: Qdrant_Filter {
        var filter = Qdrant_Filter()
        filter.must = must.map { $0.grpc }
        filter.should = should.map { $0.grpc }
        filter.mustNot = mustNot.map { $0.grpc }
        return filter
    }
}

extension Condition {
    /// Converts to the gRPC Condition representation.
    internal var grpc: Qdrant_Condition {
        var condition = Qdrant_Condition()
        switch self {
        case .field(let fieldCondition):
            condition.field = fieldCondition.grpc
        case .isEmpty(let key):
            var isEmpty = Qdrant_IsEmptyCondition()
            isEmpty.key = key
            condition.isEmpty = isEmpty
        case .isNull(let key):
            var isNull = Qdrant_IsNullCondition()
            isNull.key = key
            condition.isNull = isNull
        case .hasId(let ids):
            var hasId = Qdrant_HasIdCondition()
            hasId.hasID_p = ids.map { $0.grpc }
            condition.hasID_p = hasId
        case .filter(let filter):
            condition.filter = filter.grpc
        }
        return condition
    }
}

extension FieldCondition {
    /// Converts to the gRPC FieldCondition representation.
    internal var grpc: Qdrant_FieldCondition {
        var field = Qdrant_FieldCondition()
        field.key = key

        if let match = match {
            field.match = match.grpc
        }

        if let range = range {
            field.range = range.grpc
        }

        if let geo = geo {
            switch geo {
            case .radius(let center, let radius):
                var geoRadius = Qdrant_GeoRadius()
                geoRadius.center = center.grpc
                geoRadius.radius = Float(radius)
                field.geoRadius = geoRadius
            case .boundingBox(let topLeft, let bottomRight):
                var box = Qdrant_GeoBoundingBox()
                box.topLeft = topLeft.grpc
                box.bottomRight = bottomRight.grpc
                field.geoBoundingBox = box
            }
        }

        return field
    }
}

extension Match {
    /// Converts to the gRPC Match representation.
    internal var grpc: Qdrant_Match {
        var match = Qdrant_Match()
        switch self {
        case .keyword(let value):
            match.keyword = value
        case .integer(let value):
            match.integer = value
        case .boolean(let value):
            match.boolean = value
        case .text(let value):
            match.text = value
        case .anyKeyword(let values):
            var repeated = Qdrant_RepeatedStrings()
            repeated.strings = values
            match.keywords = repeated
        case .anyInteger(let values):
            var repeated = Qdrant_RepeatedIntegers()
            repeated.integers = values
            match.integers = repeated
        case .exceptKeyword(let values):
            var repeated = Qdrant_RepeatedStrings()
            repeated.strings = values
            match.exceptKeywords = repeated
        case .exceptInteger(let values):
            var repeated = Qdrant_RepeatedIntegers()
            repeated.integers = values
            match.exceptIntegers = repeated
        }
        return match
    }
}

extension Range {
    /// Converts to the gRPC Range representation.
    internal var grpc: Qdrant_Range {
        var range = Qdrant_Range()
        if let lt = lt { range.lt = lt }
        if let gt = gt { range.gt = gt }
        if let lte = lte { range.lte = lte }
        if let gte = gte { range.gte = gte }
        return range
    }
}

extension GeoPoint {
    /// Converts to the gRPC GeoPoint representation.
    internal var grpc: Qdrant_GeoPoint {
        var point = Qdrant_GeoPoint()
        point.lat = lat
        point.lon = lon
        return point
    }
}
