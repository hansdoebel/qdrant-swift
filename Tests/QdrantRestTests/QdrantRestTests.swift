import Foundation
import Testing

@testable import QdrantREST

@Suite("QdrantRest Tests")
struct QdrantRestTests {

    @Test("PointId Codable - Integer")
    func pointIdCodableInteger() throws {
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

    @Test("PointId Codable - UUID")
    func pointIdCodableUUID() throws {
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

    @Test("PayloadValue Codable - Integer")
    func payloadValueCodableInteger() throws {
        let value: PayloadValue = .integer(42)
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "42")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PayloadValue.self, from: data)

        if case .integer(let i) = decoded {
            #expect(i == 42)
        } else {
            Issue.record("Expected integer payload value")
        }
    }

    @Test("PayloadValue Codable - Array")
    func payloadValueCodableArray() throws {
        let value: PayloadValue = .array([.string("a"), .integer(1)])
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PayloadValue.self, from: data)

        if case .array(let arr) = decoded {
            #expect(arr.count == 2)
        } else {
            Issue.record("Expected array payload value")
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

    @Test("Filter Codable")
    func filterCodable() throws {
        let filter = Filter(
            must: [.field(FieldCondition(key: "category", match: .keyword("electronics")))]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(filter)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Filter.self, from: data)

        #expect(decoded.must.count == 1)
    }

    @Test("Point Codable")
    func pointCodable() throws {
        let point = Point(
            id: .integer(1),
            vector: [0.1, 0.2, 0.3],
            payload: ["category": .string("test")]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(point)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Point.self, from: data)

        if case .integer(let id) = decoded.id {
            #expect(id == 1)
        } else {
            Issue.record("Expected integer point id")
        }

        if case .dense(let vector) = decoded.vector {
            #expect(vector.count == 3)
        } else {
            Issue.record("Expected dense vector")
        }

        #expect(decoded.payload?["category"]?.stringValue == "test")
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

    @Test("Range Codable")
    func rangeCodable() throws {
        let range = Range(lte: 20, gte: 10)
        let encoder = JSONEncoder()
        let data = try encoder.encode(range)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Range.self, from: data)

        #expect(decoded.gte == 10)
        #expect(decoded.lte == 20)
    }

    @Test("Distance enum encoding")
    func distanceEnumEncoding() throws {
        // Test that Distance encodes to expected strings
        let encoder = JSONEncoder()

        let cosineData = try encoder.encode(Distance.cosine)
        #expect(String(data: cosineData, encoding: .utf8) == "\"Cosine\"")

        let euclidData = try encoder.encode(Distance.euclid)
        #expect(String(data: euclidData, encoding: .utf8) == "\"Euclid\"")

        let dotData = try encoder.encode(Distance.dot)
        #expect(String(data: dotData, encoding: .utf8) == "\"Dot\"")
    }

    @Test("HTTPError descriptions")
    func httpErrorDescriptions() {
        let error = HTTPError.collectionNotFound("test_collection")
        #expect(error.errorDescription?.contains("test_collection") == true)

        let networkError = HTTPError.unauthenticated
        #expect(networkError.errorDescription?.contains("Authentication") == true)
    }

    @Test("REST Client TLS Required For Remote Host")
    func restClientTLSRequired() {
        // Disabling TLS for remote host should throw
        #expect(throws: HTTPError.self) {
            _ = try QdrantRESTClient(host: "cloud.qdrant.io", useTLS: false)
        }

        // Disabling TLS for localhost should be allowed
        #expect(throws: Never.self) {
            _ = try QdrantRESTClient(host: "localhost", useTLS: false)
        }

        // Disabling TLS for 127.0.0.1 should be allowed
        #expect(throws: Never.self) {
            _ = try QdrantRESTClient(host: "127.0.0.1", useTLS: false)
        }

        // Auto TLS for remote host should work
        #expect(throws: Never.self) {
            _ = try QdrantRESTClient(host: "cloud.qdrant.io")
        }
    }
}
