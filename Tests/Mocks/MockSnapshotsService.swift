import Foundation
import QdrantCore

/// A mock implementation of `SnapshotsServiceProtocol` for unit testing.
///
/// This mock allows you to:
/// - Track which methods were called and with what arguments
/// - Configure return values and errors for each method
/// - Verify interactions in your tests
public final class MockSnapshotsService: SnapshotsServiceProtocol, @unchecked Sendable {

    // MARK: - Call Tracking

    public private(set) var createCallCount = 0
    public private(set) var createCalls: [String] = []

    public private(set) var listCallCount = 0
    public private(set) var listCalls: [String] = []

    public private(set) var deleteCallCount = 0
    public private(set) var deleteCalls: [(collection: String, snapshot: String)] = []

    public private(set) var createFullCallCount = 0

    public private(set) var listFullCallCount = 0

    public private(set) var deleteFullCallCount = 0
    public private(set) var deleteFullCalls: [String] = []

    // MARK: - Stubbed Results

    public var createResult: Result<SnapshotDescription, Error> = .success(
        SnapshotDescription(name: "test-snapshot", size: 1024)
    )
    public var listResult: Result<[SnapshotDescription], Error> = .success([])
    public var deleteResult: Result<Void, Error> = .success(())
    public var createFullResult: Result<SnapshotDescription, Error> = .success(
        SnapshotDescription(name: "full-snapshot", size: 2048)
    )
    public var listFullResult: Result<[SnapshotDescription], Error> = .success([])
    public var deleteFullResult: Result<Void, Error> = .success(())

    // MARK: - Initialization

    public init() {}

    // MARK: - Reset

    public func reset() {
        createCallCount = 0
        createCalls = []
        listCallCount = 0
        listCalls = []
        deleteCallCount = 0
        deleteCalls = []
        createFullCallCount = 0
        listFullCallCount = 0
        deleteFullCallCount = 0
        deleteFullCalls = []
    }

    // MARK: - SnapshotsServiceProtocol

    public func create(collection: String) async throws -> SnapshotDescription {
        createCallCount += 1
        createCalls.append(collection)
        return try createResult.get()
    }

    public func list(collection: String) async throws -> [SnapshotDescription] {
        listCallCount += 1
        listCalls.append(collection)
        return try listResult.get()
    }

    public func delete(collection: String, snapshot: String) async throws {
        deleteCallCount += 1
        deleteCalls.append((collection: collection, snapshot: snapshot))
        try deleteResult.get()
    }

    public func createFull() async throws -> SnapshotDescription {
        createFullCallCount += 1
        return try createFullResult.get()
    }

    public func listFull() async throws -> [SnapshotDescription] {
        listFullCallCount += 1
        return try listFullResult.get()
    }

    public func deleteFull(snapshot: String) async throws {
        deleteFullCallCount += 1
        deleteFullCalls.append(snapshot)
        try deleteFullResult.get()
    }
}
