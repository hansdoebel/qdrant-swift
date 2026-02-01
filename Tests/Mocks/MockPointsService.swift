import Foundation
import QdrantCore

/// A mock implementation of `PointsServiceProtocol` for unit testing.
///
/// This mock allows you to:
/// - Track which methods were called and with what arguments
/// - Configure return values and errors for each method
/// - Verify interactions in your tests
public final class MockPointsService: PointsServiceProtocol, @unchecked Sendable {

    // MARK: - Call Tracking

    public private(set) var upsertCallCount = 0
    public private(set) var upsertCalls: [(collection: String, points: [Point], wait: Bool)] = []

    public private(set) var getCallCount = 0
    public private(set) var getCalls:
        [(collection: String, ids: [PointID], withPayload: Bool, withVectors: Bool)] = []

    public private(set) var deleteByIdsCallCount = 0
    public private(set) var deleteByIdsCalls: [(collection: String, ids: [PointID], wait: Bool)] =
        []

    public private(set) var deleteByFilterCallCount = 0
    public private(set) var deleteByFilterCalls:
        [(collection: String, filter: Filter, wait: Bool)] = []

    public private(set) var scrollCallCount = 0
    public private(set) var scrollCalls:
        [(
            collection: String, filter: Filter?, limit: UInt32, offset: PointID?, withPayload: Bool,
            withVectors: Bool
        )] = []

    public private(set) var countCallCount = 0
    public private(set) var countCalls: [(collection: String, filter: Filter?, exact: Bool)] = []

    public private(set) var searchCallCount = 0
    public private(set) var searchCalls:
        [(
            collection: String, vector: [Float], limit: UInt64, filter: Filter?,
            scoreThreshold: Float?, offset: UInt64?, withPayload: Bool, withVectors: Bool,
            vectorName: String?
        )] = []

    public private(set) var recommendCallCount = 0
    public private(set) var recommendCalls:
        [(
            collection: String, positive: [PointID], negative: [PointID], limit: UInt64,
            filter: Filter?, scoreThreshold: Float?, withPayload: Bool, withVectors: Bool
        )] = []

    public private(set) var setPayloadCallCount = 0
    public private(set) var setPayloadCalls:
        [(collection: String, ids: [PointID], payload: [String: PayloadValue], wait: Bool)] = []

    public private(set) var deletePayloadCallCount = 0
    public private(set) var deletePayloadCalls:
        [(collection: String, ids: [PointID], keys: [String], wait: Bool)] = []

    public private(set) var clearPayloadCallCount = 0
    public private(set) var clearPayloadCalls: [(collection: String, ids: [PointID], wait: Bool)] =
        []

    public private(set) var createFieldIndexCallCount = 0
    public private(set) var createFieldIndexCalls:
        [(collection: String, fieldName: String, fieldType: FieldType, wait: Bool)] = []

    public private(set) var deleteFieldIndexCallCount = 0
    public private(set) var deleteFieldIndexCalls:
        [(collection: String, fieldName: String, wait: Bool)] = []

    // MARK: - Stubbed Results

    public var upsertResult: Result<Void, Error> = .success(())
    public var getResult: Result<[RetrievedPoint], Error> = .success([])
    public var deleteByIdsResult: Result<Void, Error> = .success(())
    public var deleteByFilterResult: Result<Void, Error> = .success(())
    public var scrollResult: Result<ScrollResult, Error> = .success(
        ScrollResult(points: [], nextPageOffset: nil))
    public var countResult: Result<UInt64, Error> = .success(0)
    public var searchResult: Result<[ScoredPoint], Error> = .success([])
    public var recommendResult: Result<[ScoredPoint], Error> = .success([])
    public var setPayloadResult: Result<Void, Error> = .success(())
    public var deletePayloadResult: Result<Void, Error> = .success(())
    public var clearPayloadResult: Result<Void, Error> = .success(())
    public var createFieldIndexResult: Result<Void, Error> = .success(())
    public var deleteFieldIndexResult: Result<Void, Error> = .success(())

    // MARK: - Initialization

    public init() {}

    // MARK: - Reset

    public func reset() {
        upsertCallCount = 0
        upsertCalls = []
        getCallCount = 0
        getCalls = []
        deleteByIdsCallCount = 0
        deleteByIdsCalls = []
        deleteByFilterCallCount = 0
        deleteByFilterCalls = []
        scrollCallCount = 0
        scrollCalls = []
        countCallCount = 0
        countCalls = []
        searchCallCount = 0
        searchCalls = []
        recommendCallCount = 0
        recommendCalls = []
        setPayloadCallCount = 0
        setPayloadCalls = []
        deletePayloadCallCount = 0
        deletePayloadCalls = []
        clearPayloadCallCount = 0
        clearPayloadCalls = []
        createFieldIndexCallCount = 0
        createFieldIndexCalls = []
        deleteFieldIndexCallCount = 0
        deleteFieldIndexCalls = []
    }

    // MARK: - PointsServiceProtocol

    public func upsert(
        collection: String,
        points: [Point],
        wait: Bool
    ) async throws {
        upsertCallCount += 1
        upsertCalls.append((collection: collection, points: points, wait: wait))
        try upsertResult.get()
    }

    public func get(
        collection: String,
        ids: [PointID],
        withPayload: Bool,
        withVectors: Bool
    ) async throws -> [RetrievedPoint] {
        getCallCount += 1
        getCalls.append(
            (collection: collection, ids: ids, withPayload: withPayload, withVectors: withVectors))
        return try getResult.get()
    }

    public func delete(
        collection: String,
        ids: [PointID],
        wait: Bool
    ) async throws {
        deleteByIdsCallCount += 1
        deleteByIdsCalls.append((collection: collection, ids: ids, wait: wait))
        try deleteByIdsResult.get()
    }

    public func delete(
        collection: String,
        filter: Filter,
        wait: Bool
    ) async throws {
        deleteByFilterCallCount += 1
        deleteByFilterCalls.append((collection: collection, filter: filter, wait: wait))
        try deleteByFilterResult.get()
    }

    public func scroll(
        collection: String,
        filter: Filter?,
        limit: UInt32,
        offset: PointID?,
        withPayload: Bool,
        withVectors: Bool
    ) async throws -> ScrollResult {
        scrollCallCount += 1
        scrollCalls.append(
            (
                collection: collection, filter: filter, limit: limit, offset: offset,
                withPayload: withPayload, withVectors: withVectors
            ))
        return try scrollResult.get()
    }

    public func count(
        collection: String,
        filter: Filter?,
        exact: Bool
    ) async throws -> UInt64 {
        countCallCount += 1
        countCalls.append((collection: collection, filter: filter, exact: exact))
        return try countResult.get()
    }

    public func search(
        collection: String,
        vector: [Float],
        limit: UInt64,
        filter: Filter?,
        scoreThreshold: Float?,
        offset: UInt64?,
        withPayload: Bool,
        withVectors: Bool,
        vectorName: String?
    ) async throws -> [ScoredPoint] {
        searchCallCount += 1
        searchCalls.append(
            (
                collection: collection, vector: vector, limit: limit, filter: filter,
                scoreThreshold: scoreThreshold, offset: offset, withPayload: withPayload,
                withVectors: withVectors, vectorName: vectorName
            ))
        return try searchResult.get()
    }

    public func recommend(
        collection: String,
        positive: [PointID],
        negative: [PointID],
        limit: UInt64,
        filter: Filter?,
        scoreThreshold: Float?,
        withPayload: Bool,
        withVectors: Bool
    ) async throws -> [ScoredPoint] {
        recommendCallCount += 1
        recommendCalls.append(
            (
                collection: collection, positive: positive, negative: negative, limit: limit,
                filter: filter, scoreThreshold: scoreThreshold, withPayload: withPayload,
                withVectors: withVectors
            ))
        return try recommendResult.get()
    }

    public func setPayload(
        collection: String,
        ids: [PointID],
        payload: [String: PayloadValue],
        wait: Bool
    ) async throws {
        setPayloadCallCount += 1
        setPayloadCalls.append((collection: collection, ids: ids, payload: payload, wait: wait))
        try setPayloadResult.get()
    }

    public func deletePayload(
        collection: String,
        ids: [PointID],
        keys: [String],
        wait: Bool
    ) async throws {
        deletePayloadCallCount += 1
        deletePayloadCalls.append((collection: collection, ids: ids, keys: keys, wait: wait))
        try deletePayloadResult.get()
    }

    public func clearPayload(
        collection: String,
        ids: [PointID],
        wait: Bool
    ) async throws {
        clearPayloadCallCount += 1
        clearPayloadCalls.append((collection: collection, ids: ids, wait: wait))
        try clearPayloadResult.get()
    }

    public func createFieldIndex(
        collection: String,
        fieldName: String,
        fieldType: FieldType,
        wait: Bool
    ) async throws {
        createFieldIndexCallCount += 1
        createFieldIndexCalls.append(
            (collection: collection, fieldName: fieldName, fieldType: fieldType, wait: wait))
        try createFieldIndexResult.get()
    }

    public func deleteFieldIndex(
        collection: String,
        fieldName: String,
        wait: Bool
    ) async throws {
        deleteFieldIndexCallCount += 1
        deleteFieldIndexCalls.append((collection: collection, fieldName: fieldName, wait: wait))
        try deleteFieldIndexResult.get()
    }
}
