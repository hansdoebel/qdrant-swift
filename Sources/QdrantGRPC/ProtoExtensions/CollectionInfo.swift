import Foundation
import QdrantCore
import QdrantProto
import SwiftProtobuf

extension CollectionStatus {
    internal init(grpc: Qdrant_CollectionStatus) {
        self =
            switch grpc {
            case .green: .green
            case .yellow: .yellow
            case .red: .red
            case .grey: .grey
            default: .unknown
            }
    }
}

extension CollectionInfo {
    internal init(name: String, grpc: Qdrant_CollectionInfo) {
        self.init(
            name: name,
            status: CollectionStatus(grpc: grpc.status),
            indexedVectorsCount: grpc.hasIndexedVectorsCount ? grpc.indexedVectorsCount : nil,
            pointsCount: grpc.hasPointsCount ? grpc.pointsCount : nil,
            segmentsCount: grpc.segmentsCount,
            createdAt: grpc.hasCreatedAt ? Date(grpc.createdAt) : nil,
            updateQueue: grpc.hasUpdateQueue
                ? UpdateQueueInfo(
                    length: grpc.updateQueue.length,
                    deferredPoints: grpc.updateQueue.hasDeferredPoints ? grpc.updateQueue.deferredPoints : nil
                )
                : nil
        )
    }
}

extension CollectionDescription {
    internal init(grpc: Qdrant_CollectionDescription) {
        self.init(name: grpc.name)
    }
}

extension Date {
    init(_ timestamp: SwiftProtobuf.Google_Protobuf_Timestamp) {
        self.init(
            timeIntervalSince1970: Double(timestamp.seconds) + Double(timestamp.nanos) / 1_000_000_000
        )
    }
}

extension VectorDatatype {
    var grpc: Qdrant_Datatype {
        switch self {
        case .default: .default
        case .float32: .float32
        case .uint8: .uint8
        case .float16: .float16
        case .turbo4: .turbo4
        case .turbo8: .turbo8
        case .turbo16: .turbo16
        }
    }
}

extension MemoryTier {
    var grpc: Qdrant_Memory {
        switch self {
        case .cold: .cold
        case .cached: .cached
        case .pinned: .pinned
        }
    }
}

extension TurboQuantBits {
    var grpc: Qdrant_TurboQuantBitSize {
        switch self {
        case .bits1: .bits1
        case .bits15: .bits15
        case .bits2: .bits2
        case .bits4: .bits4
        case .bits8: .bits8
        }
    }
}

extension TurboQuantization {
    var grpc: Qdrant_TurboQuantization {
        var message = Qdrant_TurboQuantization()
        if let bits { message.bits = bits.grpc }
        if let memory { message.memory = memory.grpc }
        if let alwaysRam { message.alwaysRam = alwaysRam }
        return message
    }
}

extension Quantization {
    var grpc: Qdrant_QuantizationConfig {
        var message = Qdrant_QuantizationConfig()
        switch self {
        case .turbo(let turbo):
            message.turboquant = turbo.grpc
        }
        return message
    }
}

extension StrictModeConfig {
    var grpc: Qdrant_StrictModeConfig {
        var message = Qdrant_StrictModeConfig()
        if let requireTenantFilter { message.requireTenantFilter = requireTenantFilter }
        if let searchMaxBatchsize { message.searchMaxBatchsize = searchMaxBatchsize }
        if let maxResidentMemoryPercent { message.maxResidentMemoryPercent = maxResidentMemoryPercent }
        return message
    }
}

extension CollectionOptions {
    var grpc: Qdrant_CreateCollection {
        var request = Qdrant_CreateCollection()
        request.vectorsConfig = vectors.grpc
        if let quantization { request.quantizationConfig = quantization.grpc }
        if let payload {
            var storage = Qdrant_PayloadStorageParams()
            if let memory = payload.memory { storage.memory = memory.grpc }
            request.payload = storage
        }
        if let idTracker {
            var tracker = Qdrant_IdTrackerParams()
            if let memory = idTracker.memory { tracker.memory = memory.grpc }
            request.idTracker = tracker
        }
        if let strictMode { request.strictModeConfig = strictMode.grpc }
        if let onDiskPayload { request.onDiskPayload = onDiskPayload }
        return request
    }
}

extension UpdateMode {
    var grpc: Qdrant_UpdateMode {
        switch self {
        case .upsert: .upsert
        case .insertOnly: .insertOnly
        case .updateOnly: .updateOnly
        }
    }
}

extension NamedVectorSpec {
    var dense: Qdrant_DenseVectorCreationConfig? {
        guard case .dense(let spec) = self else { return nil }
        var message = Qdrant_DenseVectorCreationConfig()
        message.size = spec.size
        message.distance = spec.distance.grpc
        if let datatype = spec.datatype { message.datatype = datatype.grpc }
        return message
    }

    var sparse: Qdrant_SparseVectorCreationConfig? {
        guard case .sparse(let spec) = self else { return nil }
        var message = Qdrant_SparseVectorCreationConfig()
        if let modifier = spec.modifier {
            message.modifier = modifier == .idf ? .idf : .none
        }
        if let datatype = spec.datatype { message.datatype = datatype.grpc }
        return message
    }
}

extension AliasDescription {
    internal init(grpc: Qdrant_AliasDescription) {
        self.init(aliasName: grpc.aliasName, collectionName: grpc.collectionName)
    }
}
