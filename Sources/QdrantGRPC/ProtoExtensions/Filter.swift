import Foundation
import QdrantCore
import QdrantProto
import SwiftProtobuf

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
        if let minShould {
            var message = Qdrant_MinShould()
            message.conditions = minShould.conditions.map { $0.grpc }
            message.minCount = minShould.minCount
            filter.minShould = message
        }
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
        case .nested(let key, let filter):
            var nested = Qdrant_NestedCondition()
            nested.key = key
            nested.filter = filter.grpc
            condition.nested = nested
        case .hasVector(let name):
            var hasVector = Qdrant_HasVectorCondition()
            hasVector.hasVector_p = name
            condition.hasVector_p = hasVector
        case .slice(let total, let index):
            var slice = Qdrant_SliceCondition()
            slice.total = total
            slice.index = index
            condition.slice = slice
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
            case .polygon(let polygon):
                field.geoPolygon = polygon.grpc
            }
        }

        if let valuesCount {
            field.valuesCount = valuesCount.grpc
        }

        if let datetimeRange {
            field.datetimeRange = datetimeRange.grpc
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
        case .phrase(let value):
            match.phrase = value
        case .textAny(let value):
            match.textAny = value
        case .prefix(let value):
            match.prefix = value
        case .substring(let value):
            match.substring = value
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

extension ValuesCount {
    internal var grpc: Qdrant_ValuesCount {
        var message = Qdrant_ValuesCount()
        if let lt { message.lt = lt }
        if let gt { message.gt = gt }
        if let lte { message.lte = lte }
        if let gte { message.gte = gte }
        return message
    }
}

extension DatetimeRange {
    internal var grpc: Qdrant_DatetimeRange {
        var message = Qdrant_DatetimeRange()
        if let lt { message.lt = lt.protobufTimestamp }
        if let gt { message.gt = gt.protobufTimestamp }
        if let lte { message.lte = lte.protobufTimestamp }
        if let gte { message.gte = gte.protobufTimestamp }
        return message
    }
}

extension GeoPolygon {
    internal var grpc: Qdrant_GeoPolygon {
        var message = Qdrant_GeoPolygon()
        message.exterior = exterior.lineString
        message.interiors = interiors.map(\.lineString)
        return message
    }
}

extension Date {
    var protobufTimestamp: SwiftProtobuf.Google_Protobuf_Timestamp {
        var timestamp = SwiftProtobuf.Google_Protobuf_Timestamp()
        let interval = timeIntervalSince1970
        let seconds = Int64(interval)
        timestamp.seconds = seconds
        timestamp.nanos = Int32((interval - Double(seconds)) * 1_000_000_000)
        return timestamp
    }
}

extension Array where Element == GeoPoint {
    var lineString: Qdrant_GeoLineString {
        var line = Qdrant_GeoLineString()
        line.points = map(\.grpc)
        return line
    }
}

extension FieldIndexSchema {
    internal var grpc: Qdrant_PayloadIndexParams {
        var params = Qdrant_PayloadIndexParams()
        switch type {
        case .text:
            var textParams = Qdrant_TextIndexParams()
            textParams.tokenizer = tokenizer(text?.tokenizer ?? .word)
            if let scoring = text?.scoring {
                var scoringParams = Qdrant_TextScoringParams()
                switch scoring {
                case .bm25: scoringParams.type = .bm25
                }
                textParams.scoring = scoringParams
            }
            if let stemmer = text?.stemmer {
                textParams.stemmer = stemmer.grpc
            }
            if let nested = text?.nested ?? nested {
                textParams.nested = nested
            }
            params.textIndexParams = textParams
        case .keyword:
            var keyword = Qdrant_KeywordIndexParams()
            if let nested { keyword.nested = nested }
            params.keywordIndexParams = keyword
        case .integer:
            var integer = Qdrant_IntegerIndexParams()
            if let nested { integer.nested = nested }
            params.integerIndexParams = integer
        case .float:
            var floatParams = Qdrant_FloatIndexParams()
            if let nested { floatParams.nested = nested }
            params.floatIndexParams = floatParams
        case .geo:
            var geo = Qdrant_GeoIndexParams()
            if let nested { geo.nested = nested }
            params.geoIndexParams = geo
        case .bool:
            var boolParams = Qdrant_BoolIndexParams()
            if let nested { boolParams.nested = nested }
            params.boolIndexParams = boolParams
        case .datetime:
            var datetime = Qdrant_DatetimeIndexParams()
            if let nested { datetime.nested = nested }
            params.datetimeIndexParams = datetime
        case .uuid:
            var uuid = Qdrant_UuidIndexParams()
            if let nested { uuid.nested = nested }
            params.uuidIndexParams = uuid
        }
        return params
    }
}

extension Stemmer {
    var grpc: Qdrant_StemmingAlgorithm {
        var algorithm = Qdrant_StemmingAlgorithm()
        switch self {
        case .disabled:
            algorithm.disabled = Qdrant_DisabledStemmer()
        case .snowball(let language):
            var snowball = Qdrant_SnowballParams()
            snowball.language = language
            algorithm.snowball = snowball
        }
        return algorithm
    }
}

private func tokenizer(_ value: Tokenizer) -> Qdrant_TokenizerType {
    switch value {
    case .prefix: .prefix
    case .whitespace: .whitespace
    case .word: .word
    case .multilingual: .multilingual
    case .code: .code
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
