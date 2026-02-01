import Foundation

public protocol PointsServiceProtocol: Sendable {
    func upsert(
        collection: String,
        points: [Point],
        wait: Bool
    ) async throws

    func get(
        collection: String,
        ids: [PointID],
        withPayload: Bool,
        withVectors: Bool
    ) async throws -> [RetrievedPoint]

    func delete(
        collection: String,
        ids: [PointID],
        wait: Bool
    ) async throws

    func delete(
        collection: String,
        filter: Filter,
        wait: Bool
    ) async throws

    func scroll(
        collection: String,
        filter: Filter?,
        limit: UInt32,
        offset: PointID?,
        withPayload: Bool,
        withVectors: Bool
    ) async throws -> ScrollResult

    func count(
        collection: String,
        filter: Filter?,
        exact: Bool
    ) async throws -> UInt64

    func search(
        collection: String,
        vector: [Float],
        limit: UInt64,
        filter: Filter?,
        scoreThreshold: Float?,
        offset: UInt64?,
        withPayload: Bool,
        withVectors: Bool,
        vectorName: String?
    ) async throws -> [ScoredPoint]

    func recommend(
        collection: String,
        positive: [PointID],
        negative: [PointID],
        limit: UInt64,
        filter: Filter?,
        scoreThreshold: Float?,
        withPayload: Bool,
        withVectors: Bool
    ) async throws -> [ScoredPoint]

    func setPayload(
        collection: String,
        ids: [PointID],
        payload: [String: PayloadValue],
        wait: Bool
    ) async throws

    func deletePayload(
        collection: String,
        ids: [PointID],
        keys: [String],
        wait: Bool
    ) async throws

    func clearPayload(
        collection: String,
        ids: [PointID],
        wait: Bool
    ) async throws

    func createFieldIndex(
        collection: String,
        fieldName: String,
        fieldType: FieldType,
        wait: Bool
    ) async throws

    func deleteFieldIndex(
        collection: String,
        fieldName: String,
        wait: Bool
    ) async throws
}

public enum FieldType: Sendable {
    case keyword

    case integer

    case float

    case geo

    case text

    case bool

    case datetime
}
