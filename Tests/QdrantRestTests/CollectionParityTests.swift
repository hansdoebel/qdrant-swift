import Foundation
import Testing

@testable import QdrantCore
@testable import QdrantREST

@Suite("Collection and point REST encoding")
struct RestCollectionParityTests {
    @Test("Collection options encode TurboQuant, memory placement, and strict mode")
    func options() throws {
        let options = CollectionOptions(
            vectors: .single(VectorConfig(size: 4, distance: .cosine, datatype: .turbo8, memory: .pinned)),
            quantization: .turbo(TurboQuantization(bits: .bits8, memory: .cold, alwaysRam: true)),
            payload: PayloadStorageParams(memory: .cached),
            idTracker: IdTrackerParams(memory: .cold),
            strictMode: StrictModeConfig(
                requireTenantFilter: true,
                searchMaxBatchsize: 16,
                maxResidentMemoryPercent: 70
            ),
            onDiskPayload: false
        )
        let object = try json(options)
        let vectors = object["vectors"] as? [String: Any]
        #expect(vectors?["datatype"] as? String == "turbo8")
        #expect(vectors?["memory"] as? String == "pinned")
        let turbo = (object["quantization_config"] as? [String: Any])?["turbo"] as? [String: Any]
        #expect(turbo?["bits"] as? String == "bits8")
        #expect(turbo?["memory"] as? String == "cold")
        #expect(turbo?["always_ram"] as? Bool == true)
        #expect((object["payload"] as? [String: Any])?["memory"] as? String == "cached")
        #expect((object["id_tracker"] as? [String: Any])?["memory"] as? String == "cold")
        let strict = object["strict_mode_config"] as? [String: Any]
        #expect(strict?["require_tenant_filter"] as? Bool == true)
        #expect(strict?["search_max_batchsize"] as? Int == 16 || (strict?["search_max_batchsize"] as? UInt64) == 16)
        #expect(strict?["max_resident_memory_percent"] as? Int == 70 || (strict?["max_resident_memory_percent"] as? UInt32) == 70)
        #expect(object["on_disk_payload"] as? Bool == false)
    }

    @Test("Named vector specs and upsert mode use the REST names")
    func vectors() throws {
        let dense = try json(NamedVectorSpecBody(spec: .dense(DenseVectorSpec(size: 8, distance: .dot, datatype: .turbo16))))
        #expect(dense["datatype"] as? String == "turbo16")
        let sparse = try json(NamedVectorSpecBody(spec: .sparse(SparseVectorSpec(modifier: .idf))))
        #expect(sparse["modifier"] as? String == "idf")
        let upsert = try json(UpsertPointsRequest(points: [], updateMode: .updateOnly))
        #expect(upsert["update_mode"] as? String == "update_only" || upsert["updateMode"] as? String == "update_only")
    }

    private func json(_ value: some Encodable) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(value)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
