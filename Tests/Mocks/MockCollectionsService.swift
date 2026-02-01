import Foundation
import QdrantCore

/// A mock implementation of `CollectionsServiceProtocol` for unit testing.
///
/// This mock allows you to:
/// - Track which methods were called and with what arguments
/// - Configure return values and errors for each method
/// - Verify interactions in your tests
public final class MockCollectionsService: CollectionsServiceProtocol, @unchecked Sendable {

    // MARK: - Call Tracking

    public private(set) var listCallCount = 0
    public private(set) var getCallCount = 0
    public private(set) var getCalls: [String] = []
    public private(set) var existsCallCount = 0
    public private(set) var existsCalls: [String] = []
    public private(set) var createCallCount = 0
    public private(set) var createCalls:
        [(name: String, vectorSize: UInt64, distance: Distance, onDiskPayload: Bool?)] = []
    public private(set) var deleteCallCount = 0
    public private(set) var deleteCalls: [String] = []
    public private(set) var createAliasCallCount = 0
    public private(set) var createAliasCalls: [(alias: String, collection: String)] = []
    public private(set) var deleteAliasCallCount = 0
    public private(set) var deleteAliasCalls: [String] = []
    public private(set) var listAliasesCallCount = 0
    public private(set) var listAliasesCalls: [String] = []
    public private(set) var listAllAliasesCallCount = 0

    // MARK: - Stubbed Results

    public var listResult: Result<[CollectionDescription], Error> = .success([])
    public var getResult: Result<CollectionInfo, Error> = .success(
        CollectionInfo(name: "test", status: .green)
    )
    public var existsResult: Result<Bool, Error> = .success(true)
    public var createResult: Result<Void, Error> = .success(())
    public var deleteResult: Result<Void, Error> = .success(())
    public var createAliasResult: Result<Void, Error> = .success(())
    public var deleteAliasResult: Result<Void, Error> = .success(())
    public var listAliasesResult: Result<[AliasDescription], Error> = .success([])
    public var listAllAliasesResult: Result<[AliasDescription], Error> = .success([])

    // MARK: - Initialization

    public init() {}

    // MARK: - Reset

    public func reset() {
        listCallCount = 0
        getCallCount = 0
        getCalls = []
        existsCallCount = 0
        existsCalls = []
        createCallCount = 0
        createCalls = []
        deleteCallCount = 0
        deleteCalls = []
        createAliasCallCount = 0
        createAliasCalls = []
        deleteAliasCallCount = 0
        deleteAliasCalls = []
        listAliasesCallCount = 0
        listAliasesCalls = []
        listAllAliasesCallCount = 0
    }

    // MARK: - CollectionsServiceProtocol

    public func list() async throws -> [CollectionDescription] {
        listCallCount += 1
        return try listResult.get()
    }

    public func get(name: String) async throws -> CollectionInfo {
        getCallCount += 1
        getCalls.append(name)
        return try getResult.get()
    }

    public func exists(name: String) async throws -> Bool {
        existsCallCount += 1
        existsCalls.append(name)
        return try existsResult.get()
    }

    public func create(
        name: String,
        vectorSize: UInt64,
        distance: Distance,
        onDiskPayload: Bool?
    ) async throws {
        createCallCount += 1
        createCalls.append(
            (name: name, vectorSize: vectorSize, distance: distance, onDiskPayload: onDiskPayload))
        try createResult.get()
    }

    public func delete(name: String) async throws {
        deleteCallCount += 1
        deleteCalls.append(name)
        try deleteResult.get()
    }

    public func createAlias(alias: String, collection: String) async throws {
        createAliasCallCount += 1
        createAliasCalls.append((alias: alias, collection: collection))
        try createAliasResult.get()
    }

    public func deleteAlias(alias: String) async throws {
        deleteAliasCallCount += 1
        deleteAliasCalls.append(alias)
        try deleteAliasResult.get()
    }

    public func listAliases(collection: String) async throws -> [AliasDescription] {
        listAliasesCallCount += 1
        listAliasesCalls.append(collection)
        return try listAliasesResult.get()
    }

    public func listAllAliases() async throws -> [AliasDescription] {
        listAllAliasesCallCount += 1
        return try listAllAliasesResult.get()
    }
}
