import Testing

@testable import QdrantGRPC

@Suite("QdrantGRPC Tests")
struct QdrantGRPCTests {

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

    // MARK: - Range Tests

    @Test("Range Creation")
    func rangeCreation() {
        let range = Range.between(10.0, 100.0)
        #expect(range.gte == 10.0)
        #expect(range.lte == 100.0)
    }

    // MARK: - GeoPoint Tests

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

    // MARK: - VectorConfig Tests

    @Test("VectorConfig Creation")
    func vectorConfigCreation() {
        let config = VectorConfig(size: 384, distance: .cosine)
        #expect(config.size == 384)
    }

    // MARK: - QdrantConfiguration Tests

    @Test("Configuration Defaults")
    func configurationDefaults() throws {
        let config = try QdrantConfiguration()
        #expect(config.host == "localhost")
        #expect(config.port == 6334)
        #expect(config.useTLS == false)
        #expect(config.apiKey == nil)
    }

    @Test("Configuration With TLS")
    func configurationWithTLS() throws {
        let config = try QdrantConfiguration(host: "cloud.qdrant.io", useTLS: true)
        #expect(config.useTLS == true)
    }

    @Test("Configuration Auto TLS")
    func configurationAutoTLS() throws {
        let localConfig = try QdrantConfiguration(host: "localhost")
        #expect(localConfig.useTLS == false)

        let remoteConfig = try QdrantConfiguration(host: "cloud.qdrant.io")
        #expect(remoteConfig.useTLS == true)
    }

    @Test("Configuration TLS Required For Remote Host")
    func configurationTLSRequired() {
        // Disabling TLS for remote host should throw
        #expect(throws: QdrantError.self) {
            _ = try QdrantConfiguration(host: "cloud.qdrant.io", useTLS: false)
        }

        // Disabling TLS for localhost should be allowed
        #expect(throws: Never.self) {
            _ = try QdrantConfiguration(host: "localhost", useTLS: false)
        }

        // Disabling TLS for 127.0.0.1 should be allowed
        #expect(throws: Never.self) {
            _ = try QdrantConfiguration(host: "127.0.0.1", useTLS: false)
        }
    }
}
