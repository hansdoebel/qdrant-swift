import Foundation
import Testing
import SwiftProtobuf
import QdrantProto

@Suite("Qdrant 1.20.2 usage compatibility")
struct HardwareUsageTests {
    @Test("Absent counters differ from explicitly recorded zero")
    func presence() throws {
        var usage = Qdrant_HardwareUsage()
        #expect(!usage.hasUpdatedBytes)
        #expect(!usage.hasUpdatedIndexedBytes)
        usage.updatedBytes = 0
        usage.updatedIndexedBytes = 0
        let data = try usage.serializedData()
        #expect(data == Data([0x50, 0, 0x58, 0]))
        let decoded = try Qdrant_HardwareUsage(serializedBytes: data)
        #expect(decoded.hasUpdatedBytes)
        #expect(decoded.hasUpdatedIndexedBytes)
        #expect(decoded.updatedBytes == 0)
        #expect(decoded.updatedIndexedBytes == 0)
    }

    @Test("Usage counters and future fields survive binary round trips")
    func roundTrip() throws {
        let bytes = Data([0x50, 0x96, 0x01, 0x58, 0x2a, 0x60, 0x07])
        let decoded = try Qdrant_HardwareUsage(serializedBytes: bytes)
        #expect(decoded.updatedBytes == 150)
        #expect(decoded.updatedIndexedBytes == 42)
        #expect(!decoded.unknownFields.data.isEmpty)
        let roundTrip = try Qdrant_HardwareUsage(serializedBytes: decoded.serializedData())
        #expect(roundTrip == decoded)
    }
}
