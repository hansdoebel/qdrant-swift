import Foundation

public struct Point: Sendable {
    public let id: PointID

    public let vector: VectorData

    public let payload: [String: PayloadValue]?

    public init(id: PointID, vector: VectorData, payload: [String: PayloadValue]? = nil) {
        self.id = id
        self.vector = vector
        self.payload = payload
    }

    public init(id: PointID, vector: [Float], payload: [String: PayloadValue]? = nil) {
        self.init(id: id, vector: .dense(vector), payload: payload)
    }
}

public struct ScoredPoint: Sendable {
    public let id: PointID

    public let score: Float?

    public let vector: VectorData?

    public let payload: [String: PayloadValue]?

    public let version: UInt64

    public init(
        id: PointID,
        score: Float?,
        vector: VectorData?,
        payload: [String: PayloadValue]?,
        version: UInt64
    ) {
        self.id = id
        self.score = score
        self.vector = vector
        self.payload = payload
        self.version = version
    }
}

public struct RetrievedPoint: Sendable {
    public let id: PointID

    public let vector: VectorData?

    public let payload: [String: PayloadValue]?

    public init(
        id: PointID,
        vector: VectorData?,
        payload: [String: PayloadValue]?
    ) {
        self.id = id
        self.vector = vector
        self.payload = payload
    }
}

public struct ScrollResult: Sendable {
    public let points: [RetrievedPoint]

    public let nextPageOffset: PointID?

    public init(points: [RetrievedPoint], nextPageOffset: PointID?) {
        self.points = points
        self.nextPageOffset = nextPageOffset
    }
}
