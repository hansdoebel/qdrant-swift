import Testing
import Foundation
@testable import QdrantCore

@Suite("QdrantCore Model Tests")
struct QdrantCoreTests {

    // MARK: - PointID Tests

    @Test("PointID Integer")
    func pointIDInteger() {
        let id: PointID = .integer(42)
        #expect(id.description == "42")
    }

    @Test("PointID UUID")
    func pointIDUUID() {
        let id: PointID = .uuid("550e8400-e29b-41d4-a716-446655440000")
        #expect(id.description == "550e8400-e29b-41d4-a716-446655440000")
    }

    @Test("PointID Integer Literal")
    func pointIDIntegerLiteral() {
        let id: PointID = 123
        #expect(id.description == "123")
    }

    @Test("PointID String Literal")
    func pointIDStringLiteral() {
        let id: PointID = "test-uuid"
        #expect(id.description == "test-uuid")
    }

    @Test("PointID Codable - Integer")
    func pointIDCodableInteger() throws {
        let id: PointID = .integer(42)
        let encoder = JSONEncoder()
        let data = try encoder.encode(id)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "42")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PointID.self, from: data)

        if case .integer(let value) = decoded {
            #expect(value == 42)
        } else {
            Issue.record("Expected integer point id")
        }
    }

    @Test("PointID Codable - UUID")
    func pointIDCodableUUID() throws {
        let id: PointID = .uuid("abc-123")
        let encoder = JSONEncoder()
        let data = try encoder.encode(id)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "\"abc-123\"")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PointID.self, from: data)

        if case .uuid(let value) = decoded {
            #expect(value == "abc-123")
        } else {
            Issue.record("Expected uuid point id")
        }
    }

    // MARK: - PayloadValue Tests

    @Test("PayloadValue String")
    func payloadValueString() {
        let value: PayloadValue = "hello"
        #expect(value.stringValue == "hello")
    }

    @Test("PayloadValue Integer")
    func payloadValueInteger() {
        let value: PayloadValue = 42
        #expect(value.integerValue == 42)
    }

    @Test("PayloadValue Double")
    func payloadValueDouble() {
        let value: PayloadValue = 3.14
        #expect(value.doubleValue == 3.14)
    }

    @Test("PayloadValue Bool")
    func payloadValueBool() {
        let value: PayloadValue = true
        #expect(value.boolValue == true)
    }

    @Test("PayloadValue Array")
    func payloadValueArray() {
        let value: PayloadValue = ["a", "b", "c"]
        #expect(value.arrayValue?.count == 3)
    }

    @Test("PayloadValue Object")
    func payloadValueObject() {
        let value: PayloadValue = ["key": "value", "num": 42]
        #expect(value.objectValue != nil)
        #expect(value["key"]?.stringValue == "value")
        #expect(value["num"]?.integerValue == 42)
    }

    @Test("PayloadValue Codable - String")
    func payloadValueCodableString() throws {
        let value: PayloadValue = .string("hello")
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "\"hello\"")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PayloadValue.self, from: data)

        if case .string(let s) = decoded {
            #expect(s == "hello")
        } else {
            Issue.record("Expected string payload value")
        }
    }

    @Test("PayloadValue Codable - Object")
    func payloadValueCodableObject() throws {
        let value: PayloadValue = .object(["key": .string("value")])
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PayloadValue.self, from: data)

        if case .object(let obj) = decoded {
            #expect(obj["key"]?.stringValue == "value")
        } else {
            Issue.record("Expected object payload value")
        }
    }

    // MARK: - Filter Tests

    @Test("Filter Creation")
    func filterCreation() {
        let filter = Filter(
            must: [.field(key: "status", match: .exact("active"))],
            should: [.field(key: "priority", match: .exact(1))],
            mustNot: [.field(key: "archived", match: .exact(true))]
        )

        #expect(filter.must.count == 1)
        #expect(filter.should.count == 1)
        #expect(filter.mustNot.count == 1)
    }

    @Test("Range Creation")
    func rangeCreation() {
        let range = Range.between(10.0, 100.0)
        #expect(range.gte == 10.0)
        #expect(range.lte == 100.0)
    }

    @Test("GeoPoint Creation")
    func geoPointCreation() {
        let point = GeoPoint(lat: 40.7128, lon: -74.0060)
        #expect(point.lat == 40.7128)
        #expect(point.lon == -74.0060)
    }

    // MARK: - Distance Tests

    @Test("Distance enum values")
    func distanceEnumValues() {
        #expect(Distance.cosine == .cosine)
        #expect(Distance.euclid == .euclid)
        #expect(Distance.dot == .dot)
        #expect(Distance.manhattan == .manhattan)
    }

    @Test("Distance Codable")
    func distanceCodable() throws {
        let distance = Distance.cosine
        let encoder = JSONEncoder()
        let data = try encoder.encode(distance)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "\"Cosine\"")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Distance.self, from: data)
        #expect(decoded == .cosine)
    }

    // MARK: - VectorData Tests

    @Test("VectorData Dense")
    func vectorDataDense() {
        let vector: VectorData = .dense([0.1, 0.2, 0.3])
        if case .dense(let arr) = vector {
            #expect(arr.count == 3)
        } else {
            Issue.record("Expected dense vector")
        }
    }

    @Test("VectorData Named")
    func vectorDataNamed() {
        let vector: VectorData = .named(["text": [0.1, 0.2], "image": [0.3, 0.4]])
        if case .named(let dict) = vector {
            #expect(dict["text"]?.count == 2)
            #expect(dict["image"]?.count == 2)
        } else {
            Issue.record("Expected named vectors")
        }
    }

    @Test("VectorData Codable - Dense")
    func vectorDataCodableDense() throws {
        let vector: VectorData = .dense([0.1, 0.2, 0.3])
        let encoder = JSONEncoder()
        let data = try encoder.encode(vector)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VectorData.self, from: data)

        if case .dense(let arr) = decoded {
            #expect(arr.count == 3)
        } else {
            Issue.record("Expected dense vector")
        }
    }

    @Test("VectorData Codable - Named")
    func vectorDataCodableNamed() throws {
        let vector: VectorData = .named(["text": [0.1, 0.2], "image": [0.3, 0.4]])
        let encoder = JSONEncoder()
        let data = try encoder.encode(vector)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VectorData.self, from: data)

        if case .named(let dict) = decoded {
            #expect(dict["text"]?.count == 2)
            #expect(dict["image"]?.count == 2)
        } else {
            Issue.record("Expected named vectors")
        }
    }

    // MARK: - Point Tests

    @Test("Point Creation")
    func pointCreation() {
        let point = Point(
            id: .integer(1),
            vector: [0.1, 0.2, 0.3],
            payload: ["category": .string("test")]
        )

        if case .integer(let id) = point.id {
            #expect(id == 1)
        } else {
            Issue.record("Expected integer point id")
        }

        if case .dense(let vec) = point.vector {
            #expect(vec.count == 3)
        } else {
            Issue.record("Expected dense vector")
        }

        #expect(point.payload?["category"]?.stringValue == "test")
    }
}
