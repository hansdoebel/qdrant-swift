import Foundation
import Testing
@testable import QdrantREST

@Suite("Qdrant 1.20.2 REST usage compatibility")
struct UsageCompatibilityTests {
    @Test("Result decoding tolerates absent, null and extended usage", arguments: [
        "",
        ",\"usage\":null",
        ",\"usage\":{}",
        ",\"usage\":{\"cpu\":null,\"vector_io_read\":null}",
        ",\"usage\":{\"cpu\":0,\"remote_io_cached_read\":2,\"remote_io_non_cached_read\":3,\"updated_bytes\":150,\"updated_indexed_bytes\":42}"
    ])
    func envelopes(usage: String) throws {
        let query = Data("{\"result\":{\"points\":[]},\"status\":\"ok\"\(usage)}".utf8)
        let result = try JSONDecoder().decode(QueryResponse.self, from: query)
        #expect(result.result?.points.isEmpty == true)
        let count = Data("{\"result\":{\"count\":7},\"status\":\"ok\"\(usage)}".utf8)
        #expect(try JSONDecoder().decode(CountResponse.self, from: count).result?.count == 7)
    }
}
