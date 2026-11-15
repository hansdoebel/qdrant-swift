import Testing
import QdrantProto

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

    // MARK: - Qdrant v1.20.1 generated symbols

    @Test("Generated protos include the v1.20.1 public messages")
    func generatedProtosIncludeV120Symbols() {
        #expect(Qdrant_Datatype.turbo8.rawValue == 5)
        #expect(Qdrant_Datatype.turbo16.rawValue == 6)
        #expect(Qdrant_Memory.cold.rawValue == 1)
        #expect(Qdrant_Memory.cached.rawValue == 2)
        #expect(Qdrant_Memory.pinned.rawValue == 3)
        #expect(Qdrant_UpdateMode.insertOnly.rawValue == 1)
        #expect(Qdrant_UpdateMode.updateOnly.rawValue == 2)
        #expect(Qdrant_TokenizerType.code.rawValue == 5)
        #expect(Qdrant_TextScoringType.bm25.rawValue == 0)
        #expect(Qdrant_TurboQuantBitSize.bits8.rawValue == 4)

        var slice = Qdrant_SliceCondition()
        slice.total = 4
        slice.index = 1
        #expect(slice.total == 4)

        var match = Qdrant_Match()
        match.prefix = "usr_"
        #expect(match.prefix == "usr_")
        match.substring = "token"
        #expect(match.substring == "token")

        var expression = Qdrant_Expression()
        expression.acosh = Qdrant_Expression()
        if case .acosh = expression.variant {
            #expect(Bool(true))
        } else {
            Issue.record("Expected acosh expression")
        }
        var max = Qdrant_MaxExpression()
        max.max = [Qdrant_Expression()]
        expression.max = max
        if case .max(let value) = expression.variant {
            #expect(value.max.count == 1)
        } else {
            Issue.record("Expected max expression")
        }

        var text = Qdrant_TextQuery()
        text.query = "time travel"
        var bm25 = Qdrant_Bm25Params()
        bm25.k = 1.2
        bm25.b = 0.75
        text.bm25 = bm25
        #expect(text.query == "time travel")
        #expect(text.bm25.k == 1.2)

        var rrf = Qdrant_Rrf()
        rrf.k = 60
        rrf.weights = [1, 0.5]
        #expect(rrf.weights == [1, 0.5])

        var strict = Qdrant_StrictModeConfig()
        strict.requireTenantFilter = true
        strict.searchMaxBatchsize = 64
        strict.maxResidentMemoryPercent = 80
        #expect(strict.hasRequireTenantFilter)
        #expect(strict.hasSearchMaxBatchsize)
        #expect(strict.hasMaxResidentMemoryPercent)

        var info = Qdrant_CollectionInfo()
        info.updateQueue.length = 3
        #expect(info.hasUpdateQueue)
        #expect(info.updateQueue.length == 3)
    }
}
