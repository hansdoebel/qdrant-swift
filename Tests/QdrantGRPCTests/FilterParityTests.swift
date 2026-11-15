import Foundation
import Testing
import QdrantProto

@testable import QdrantCore
@testable import QdrantGRPC
@testable import QdrantMocks

@Suite("Filter and index gRPC mapping")
struct FilterParityTests {
    @Test("Filter clauses cover min_should, nested, has_vector, and slice")
    func filterClauses() {
        let filter = Filter(
            must: [.nested(key: "offers", filter: Filter(must: [.field(key: "shop", match: .exact("acme"))]))],
            minShould: MinShould(conditions: [.hasVector("image"), .slice(total: 4, index: 1)], minCount: 1)
        )
        let grpc = filter.grpc
        #expect(grpc.minShould.minCount == 1)
        #expect(grpc.minShould.conditions.count == 2)
        if case .hasVector_p(let value) = grpc.minShould.conditions[0].conditionOneOf {
            #expect(value.hasVector_p == "image")
        } else {
            Issue.record("Expected has_vector")
        }
        if case .slice(let value) = grpc.minShould.conditions[1].conditionOneOf {
            #expect(value.total == 4)
            #expect(value.index == 1)
        } else {
            Issue.record("Expected slice")
        }
        if case .nested(let nested) = grpc.must[0].conditionOneOf {
            #expect(nested.key == "offers")
        } else {
            Issue.record("Expected nested")
        }
    }

    @Test("Match and field conditions cover the 1.20 predicates")
    func predicates() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let polygon = GeoPolygon(
            exterior: [
                GeoPoint(lat: 0, lon: 0),
                GeoPoint(lat: 0, lon: 1),
                GeoPoint(lat: 1, lon: 1),
                GeoPoint(lat: 0, lon: 0),
            ]
        )
        let condition = FieldCondition(
            key: "title",
            match: .prefix("usr_")
        )
        #expect(condition.grpc.match.prefix == "usr_")
        #expect(FieldCondition(key: "path", match: .substring("token")).grpc.match.substring == "token")
        #expect(FieldCondition(key: "body", match: .phrase("time travel")).grpc.match.phrase == "time travel")
        #expect(FieldCondition(key: "body", match: .textAny("qdrant")).grpc.match.textAny == "qdrant")
        #expect(FieldCondition(key: "tags", valuesCount: ValuesCount(lte: 3, gte: 1)).grpc.valuesCount.gte == 1)
        let dated = FieldCondition(key: "created", datetimeRange: DatetimeRange(gte: date))
        #expect(dated.grpc.datetimeRange.gte.seconds == 1_700_000_000)
        let geo = FieldCondition(key: "location", geo: .polygon(polygon))
        #expect(geo.grpc.geoPolygon.exterior.points.count == 4)
    }

    @Test("Text indexes carry the code tokenizer, BM25 scoring, a disabled stemmer, and nested")
    func textIndex() {
        let schema = FieldIndexSchema.text(
            TextIndexOptions(
                tokenizer: .code,
                scoring: .bm25,
                stemmer: .disabled,
                nested: "offers"
            )
        )
        let params = schema.grpc
        #expect(params.textIndexParams.tokenizer == .code)
        #expect(params.textIndexParams.scoring.type == .bm25)
        if case .disabled = params.textIndexParams.stemmer.stemmingParams {} else {
            Issue.record("Expected a disabled stemmer")
        }
        #expect(params.textIndexParams.nested == "offers")
        #expect(FieldType.uuid.grpc == .uuid)
    }

    @Test("The mock records schema-based field indexes")
    func mockIndex() async throws {
        let mock = MockPointsService()
        let schema = FieldIndexSchema.text(TextIndexOptions(tokenizer: .code, scoring: .bm25))
        try await mock.createFieldIndex(collection: "books", fieldName: "title", schema: schema, wait: true)
        #expect(mock.createFieldSchemaCalls.count == 1)
        #expect(mock.createFieldSchemaCalls[0].schema.text?.tokenizer == .code)
    }

    @Test("Pre-1970 timestamps keep nanos non-negative")
    func historicalTimestamp() {
        let timestamp = Date(timeIntervalSince1970: -0.5).protobufTimestamp
        #expect(timestamp.seconds == -1)
        #expect(timestamp.nanos == 500_000_000)
    }

    @Test("A wait timeout is not treated as an applied update")
    func operationStatus() throws {
        var response = Qdrant_PointsOperationResponse()
        var result = Qdrant_UpdateResult()
        result.status = .waitTimeout
        response.result = result
        #expect(throws: QdrantError.self) {
            try response.ensureApplied("Create vector name")
        }
        result.status = .completed
        response.result = result
        try response.ensureApplied("Create vector name")
    }
}
