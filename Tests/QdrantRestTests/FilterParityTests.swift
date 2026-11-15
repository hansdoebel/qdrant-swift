import Foundation
import Testing

@testable import QdrantCore
@testable import QdrantREST

@Suite("Filter and index REST encoding")
struct RestFilterParityTests {
    @Test("New filter JSON uses the documented field names")
    func filterJSON() throws {
        let filter = Filter(
            must: [
                .field(key: "title", match: .prefix("usr_")),
                .field(key: "path", match: .substring("token")),
                .field(key: "body", match: .phrase("time travel")),
                .field(key: "tags", match: .textAny("qdrant")),
                .hasVector("image"),
                .slice(total: 4, index: 1),
            ],
            minShould: MinShould(
                conditions: [.nested(key: "offers", filter: Filter(must: [.field(key: "shop", match: .exact("acme"))]))],
                minCount: 1
            )
        )
        let object = try jsonObject(filter)
        let must = object["must"] as? [[String: Any]]
        #expect((must?[0]["match"] as? [String: Any])?["prefix"] as? String == "usr_")
        #expect((must?[1]["match"] as? [String: Any])?["substring"] as? String == "token")
        #expect((must?[2]["match"] as? [String: Any])?["phrase"] as? String == "time travel")
        #expect((must?[3]["match"] as? [String: Any])?["text_any"] as? String == "qdrant")
        #expect(must?[4]["has_vector"] as? String == "image")
        let slice = must?[5]["slice"] as? [String: Any]
        #expect(slice?["total"] as? Int == 4 || (slice?["total"] as? UInt32) == 4)
        let minShould = object["min_should"] as? [String: Any]
        #expect(minShould?["min_count"] as? Int == 1 || (minShould?["min_count"] as? UInt64) == 1)
        let nested = ((minShould?["conditions"] as? [[String: Any]])?.first)?["nested"] as? [String: Any]
        #expect(nested?["key"] as? String == "offers")
    }

    @Test("Datetime range, value count, and geo polygon encode")
    func fieldPredicates() throws {
        let dated = FieldCondition(
            key: "created",
            datetimeRange: DatetimeRange(gte: Date(timeIntervalSince1970: 1_700_000_000))
        )
        let datedJSON = try jsonObject(dated)
        #expect((datedJSON["datetime_range"] as? [String: Any])?["gte"] as? String == "2023-11-14T22:13:20.000000Z")

        let counted = try jsonObject(FieldCondition(key: "tags", valuesCount: ValuesCount(gte: 2)))
        #expect((counted["values_count"] as? [String: Any])?["gte"] != nil)

        let polygon = GeoPolygon(exterior: [
            GeoPoint(lat: 0, lon: 0),
            GeoPoint(lat: 1, lon: 0),
            GeoPoint(lat: 1, lon: 1),
            GeoPoint(lat: 0, lon: 0),
        ])
        let geo = try jsonObject(FieldCondition(key: "location", geo: .polygon(polygon)))
        let body = geo["geo_polygon"] as? [String: Any]
        let exterior = body?["exterior"] as? [String: Any]
        #expect((exterior?["points"] as? [Any])?.count == 4)
    }

    @Test("Text index schema encodes tokenizer, BM25, disabled stemming, and nested")
    func textIndex() throws {
        let schema = FieldIndexSchema.text(
            TextIndexOptions(tokenizer: .code, scoring: .bm25, stemmer: .disabled, nested: "offers")
        )
        let object = try jsonObject(schema)
        #expect(object["type"] as? String == "text")
        #expect(object["tokenizer"] as? String == "code")
        #expect((object["scoring"] as? [String: Any])?["type"] as? String == "bm25")
        #expect((object["stemmer"] as? [String: Any])?["type"] as? String == "none")
        #expect(object["nested"] as? String == "offers")
        let uuid = try JSONEncoder().encode(FieldIndexSchema(type: .uuid))
        #expect(String(data: uuid, encoding: .utf8) == "\"uuid\"")
    }

    @Test("Datetime bounds keep fractional seconds")
    func fractionalDatetime() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(0.123456)
        let data = try JSONEncoder().encode(DatetimeRange(lt: date))
        #expect(String(data: data, encoding: .utf8)?.contains(".123456") == true)
        let loaded = try JSONDecoder().decode(DatetimeRange.self, from: data)
        let delta = abs((loaded.lt?.timeIntervalSince1970 ?? 0) - date.timeIntervalSince1970)
        #expect(delta < 0.000001)
    }
}
