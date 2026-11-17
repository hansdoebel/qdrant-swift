public enum VectorDatatype: String, Sendable, Codable {
    case `default`
    case float32
    case uint8
    case float16
    case turbo4
    case turbo8
    case turbo16
}

public enum MemoryTier: String, Sendable, Codable {
    case cold
    case cached
    case pinned
}

public enum TurboQuantBits: String, Sendable, Codable {
    case bits1
    case bits15 = "bits1_5"
    case bits2
    case bits4
    case bits8
}

public struct TurboQuantization: Sendable {
    public var bits: TurboQuantBits?

    public var memory: MemoryTier?

    @available(*, deprecated, message: "Use memory instead")
    public var alwaysRam: Bool?

    public init(bits: TurboQuantBits? = nil, memory: MemoryTier? = nil, alwaysRam: Bool? = nil) {
        self.bits = bits
        self.memory = memory
        self.alwaysRam = alwaysRam
    }
}

public enum Quantization: Sendable {
    case turbo(TurboQuantization)
}

public struct PayloadStorageParams: Sendable {
    public var memory: MemoryTier?

    public init(memory: MemoryTier? = nil) {
        self.memory = memory
    }
}

public struct IdTrackerParams: Sendable {
    public var memory: MemoryTier?

    public init(memory: MemoryTier? = nil) {
        self.memory = memory
    }
}

public struct StrictModeConfig: Sendable {
    public var enabled: Bool?
    public var requireTenantFilter: Bool?

    public var searchMaxBatchsize: UInt64?

    @available(*, deprecated, message: "Memory is node-wide. Use the global quota config instead.")
    public var maxResidentMemoryPercent: UInt32?

    public init(
        enabled: Bool? = nil,
        requireTenantFilter: Bool? = nil,
        searchMaxBatchsize: UInt64? = nil,
        maxResidentMemoryPercent: UInt32? = nil
    ) {
        self.enabled = enabled
        self.requireTenantFilter = requireTenantFilter
        self.searchMaxBatchsize = searchMaxBatchsize
        self.maxResidentMemoryPercent = maxResidentMemoryPercent
    }
}

public struct CollectionOptions: Sendable {
    public var vectors: VectorsConfig

    public var quantization: Quantization?

    public var payload: PayloadStorageParams?

    public var idTracker: IdTrackerParams?

    public var strictMode: StrictModeConfig?

    @available(*, deprecated, message: "Use payload.memory instead")
    public var onDiskPayload: Bool?

    public init(
        vectors: VectorsConfig,
        quantization: Quantization? = nil,
        payload: PayloadStorageParams? = nil,
        idTracker: IdTrackerParams? = nil,
        strictMode: StrictModeConfig? = nil,
        onDiskPayload: Bool? = nil
    ) {
        self.vectors = vectors
        self.quantization = quantization
        self.payload = payload
        self.idTracker = idTracker
        self.strictMode = strictMode
        self.onDiskPayload = onDiskPayload
    }
}

public enum UpdateMode: String, Sendable, Codable {
    case upsert
    case insertOnly = "insert_only"
    case updateOnly = "update_only"
}

public enum SparseModifier: String, Sendable, Codable {
    case none
    case idf
}

public struct DenseVectorSpec: Sendable {
    public var size: UInt64
    public var distance: Distance
    public var datatype: VectorDatatype?

    public init(size: UInt64, distance: Distance, datatype: VectorDatatype? = nil) {
        self.size = size
        self.distance = distance
        self.datatype = datatype
    }
}

public struct SparseVectorSpec: Sendable {
    public var modifier: SparseModifier?
    public var datatype: VectorDatatype?

    public init(modifier: SparseModifier? = nil, datatype: VectorDatatype? = nil) {
        self.modifier = modifier
        self.datatype = datatype
    }
}

public enum NamedVectorSpec: Sendable {
    case dense(DenseVectorSpec)
    case sparse(SparseVectorSpec)
}
