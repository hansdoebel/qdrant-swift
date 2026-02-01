import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import QdrantCore
import QdrantProto

/// Service for managing points in Qdrant collections.
/// This facade delegates to specialized internal services for each operation category.
public final class PointsService: Sendable {
    private let base: PointsServiceBase
    private let crud: PointsCRUDService
    private let search: SearchService
    private let query: QueryService
    private let recommend: RecommendService
    private let discover: DiscoverService
    private let payload: PayloadService
    private let vector: VectorService
    private let index: IndexService
    private let batch: BatchService

    internal init(client: GRPCClient<HTTP2ClientTransport.Posix>, apiKey: String?) {
        self.base = PointsServiceBase(client: client, apiKey: apiKey)
        self.crud = PointsCRUDService(base: base)
        self.search = SearchService(base: base)
        self.query = QueryService(base: base)
        self.recommend = RecommendService(base: base)
        self.discover = DiscoverService(base: base)
        self.payload = PayloadService(base: base)
        self.vector = VectorService(base: base)
        self.index = IndexService(base: base)
        self.batch = BatchService(base: base)
    }

    /// Inserts or updates points in a collection.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - points: The points to upsert.
    ///   - wait: Whether to wait for the operation to complete.
    public func upsert(
        collection: String,
        points: [Point],
        wait: Bool = true
    ) async throws {
        try await crud.upsert(collection: collection, points: points, wait: wait)
    }

    /// Retrieves points by their IDs.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - ids: The point IDs to retrieve.
    ///   - withPayload: Whether to include payload.
    ///   - withVectors: Whether to include vectors.
    /// - Returns: An array of retrieved points.
    public func get(
        collection: String,
        ids: [PointID],
        withPayload: Bool = true,
        withVectors: Bool = false
    ) async throws -> [RetrievedPoint] {
        try await crud.get(
            collection: collection, ids: ids, withPayload: withPayload, withVectors: withVectors)
    }

    /// Deletes points by their IDs.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - ids: The point IDs to delete.
    ///   - wait: Whether to wait for the operation to complete.
    public func delete(
        collection: String,
        ids: [PointID],
        wait: Bool = true
    ) async throws {
        try await crud.delete(collection: collection, ids: ids, wait: wait)
    }

    /// Deletes points matching a filter.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - filter: The filter to match points to delete.
    ///   - wait: Whether to wait for the operation to complete.
    public func delete(
        collection: String,
        filter: Filter,
        wait: Bool = true
    ) async throws {
        try await crud.delete(collection: collection, filter: filter, wait: wait)
    }

    /// Scrolls through points in a collection.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - filter: Optional filter to apply.
    ///   - limit: Maximum number of points to return.
    ///   - offset: Offset point ID to start from.
    ///   - withPayload: Whether to include payload.
    ///   - withVectors: Whether to include vectors.
    /// - Returns: A scroll result with points and next page offset.
    public func scroll(
        collection: String,
        filter: Filter? = nil,
        limit: UInt32 = 10,
        offset: PointID? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false
    ) async throws -> ScrollResult {
        try await crud.scroll(
            collection: collection, filter: filter, limit: limit, offset: offset,
            withPayload: withPayload, withVectors: withVectors)
    }

    /// Counts the number of points in a collection.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - filter: Optional filter to apply.
    ///   - exact: Whether to perform exact count (slower but precise).
    /// - Returns: The number of points.
    public func count(
        collection: String,
        filter: Filter? = nil,
        exact: Bool = true
    ) async throws -> UInt64 {
        try await crud.count(collection: collection, filter: filter, exact: exact)
    }

    /// Searches for similar vectors.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - vector: The query vector.
    ///   - limit: Maximum number of results.
    ///   - filter: Optional filter to apply.
    ///   - scoreThreshold: Minimum score threshold.
    ///   - offset: Number of results to skip.
    ///   - withPayload: Whether to include payload.
    ///   - withVectors: Whether to include vectors.
    ///   - vectorName: Name of the vector field (for multi-vector collections).
    /// - Returns: An array of scored points.
    public func search(
        collection: String,
        vector: [Float],
        limit: UInt64 = 10,
        filter: Filter? = nil,
        scoreThreshold: Float? = nil,
        offset: UInt64? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false,
        vectorName: String? = nil
    ) async throws -> [ScoredPoint] {
        try await search.search(
            collection: collection, vector: vector, limit: limit, filter: filter,
            scoreThreshold: scoreThreshold, offset: offset, withPayload: withPayload,
            withVectors: withVectors, vectorName: vectorName)
    }

    /// Searches for similar vectors (convenience method with Double array).
    public func search(
        collection: String,
        vector: [Double],
        limit: UInt64 = 10,
        filter: Filter? = nil,
        scoreThreshold: Float? = nil,
        offset: UInt64? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false,
        vectorName: String? = nil
    ) async throws -> [ScoredPoint] {
        try await search(
            collection: collection,
            vector: vector.map { Float($0) },
            limit: limit,
            filter: filter,
            scoreThreshold: scoreThreshold,
            offset: offset,
            withPayload: withPayload,
            withVectors: withVectors,
            vectorName: vectorName
        )
    }

    /// Performs multiple searches in a single request.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - searches: The search requests.
    /// - Returns: An array of search results (array of scored points for each search).
    public func searchBatch(
        collection: String,
        searches: [SearchRequest]
    ) async throws -> [[ScoredPoint]] {
        try await search.searchBatch(collection: collection, searches: searches)
    }

    /// Searches for groups of similar vectors.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - vector: The query vector.
    ///   - groupBy: The field to group by.
    ///   - limit: Maximum number of groups.
    ///   - groupSize: Maximum number of points per group.
    ///   - filter: Optional filter to apply.
    ///   - withPayload: Whether to include payload.
    /// - Returns: Array of point groups.
    public func searchGroups(
        collection: String,
        vector: [Float],
        groupBy: String,
        limit: UInt32 = 10,
        groupSize: UInt32 = 3,
        filter: Filter? = nil,
        withPayload: Bool = true
    ) async throws -> [PointGroup] {
        try await search.searchGroups(
            collection: collection, vector: vector, groupBy: groupBy, limit: limit,
            groupSize: groupSize, filter: filter, withPayload: withPayload)
    }

    /// Computes distance matrix between sampled points (pairs format).
    public func searchMatrixPairs(
        collection: String,
        filter: Filter? = nil,
        sample: UInt64 = 10,
        limit: UInt64 = 3,
        using: String? = nil
    ) async throws -> SearchMatrixPairsResult {
        try await search.searchMatrixPairs(
            collection: collection, filter: filter, sample: sample, limit: limit, using: using)
    }

    /// Computes distance matrix between sampled points (offsets format).
    public func searchMatrixOffsets(
        collection: String,
        filter: Filter? = nil,
        sample: UInt64 = 10,
        limit: UInt64 = 3,
        using: String? = nil
    ) async throws -> SearchMatrixOffsetsResult {
        try await search.searchMatrixOffsets(
            collection: collection, filter: filter, sample: sample, limit: limit, using: using)
    }

    /// Universal query API - performs various types of queries.
    public func query(
        collection: String,
        query queryInput: QueryInput? = nil,
        prefetch: [PrefetchQuery] = [],
        using: String? = nil,
        filter: Filter? = nil,
        limit: UInt64 = 10,
        offset: UInt64? = nil,
        scoreThreshold: Float? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false
    ) async throws -> [ScoredPoint] {
        try await self.query.query(
            collection: collection, query: queryInput, prefetch: prefetch, using: using,
            filter: filter, limit: limit, offset: offset, scoreThreshold: scoreThreshold,
            withPayload: withPayload, withVectors: withVectors)
    }

    /// Performs multiple queries in a single batch request.
    public func queryBatch(
        collection: String,
        queries: [QueryRequest]
    ) async throws -> [[ScoredPoint]] {
        try await query.queryBatch(collection: collection, queries: queries)
    }

    /// Performs a grouped query.
    public func queryGroups(
        collection: String,
        query queryInput: QueryInput? = nil,
        groupBy: String,
        limit: UInt64 = 10,
        groupSize: UInt64 = 3,
        prefetch: [PrefetchQuery] = [],
        using: String? = nil,
        filter: Filter? = nil,
        scoreThreshold: Float? = nil,
        withPayload: Bool = true
    ) async throws -> [PointGroup] {
        try await query.queryGroups(
            collection: collection, query: queryInput, groupBy: groupBy, limit: limit,
            groupSize: groupSize, prefetch: prefetch, using: using, filter: filter,
            scoreThreshold: scoreThreshold, withPayload: withPayload)
    }

    /// Finds points similar to the given positive examples and dissimilar to negative examples.
    public func recommend(
        collection: String,
        positive: [PointID],
        negative: [PointID] = [],
        limit: UInt64 = 10,
        filter: Filter? = nil,
        scoreThreshold: Float? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false
    ) async throws -> [ScoredPoint] {
        try await recommend.recommend(
            collection: collection, positive: positive, negative: negative, limit: limit,
            filter: filter, scoreThreshold: scoreThreshold, withPayload: withPayload,
            withVectors: withVectors)
    }

    /// Performs multiple recommend requests in a single batch.
    public func recommendBatch(
        collection: String,
        requests: [RecommendRequest]
    ) async throws -> [[ScoredPoint]] {
        try await recommend.recommendBatch(collection: collection, requests: requests)
    }

    /// Finds groups of points similar to positive examples.
    public func recommendGroups(
        collection: String,
        positive: [PointID],
        negative: [PointID] = [],
        groupBy: String,
        limit: UInt32 = 10,
        groupSize: UInt32 = 3,
        filter: Filter? = nil,
        scoreThreshold: Float? = nil,
        withPayload: Bool = true
    ) async throws -> [PointGroup] {
        try await recommend.recommendGroups(
            collection: collection, positive: positive, negative: negative, groupBy: groupBy,
            limit: limit, groupSize: groupSize, filter: filter, scoreThreshold: scoreThreshold,
            withPayload: withPayload)
    }

    /// Discovers points using context pairs (positive/negative examples).
    public func discover(
        collection: String,
        target: DiscoverTarget,
        context: [ContextPair],
        limit: UInt64 = 10,
        filter: Filter? = nil,
        withPayload: Bool = true
    ) async throws -> [ScoredPoint] {
        try await discover.discover(
            collection: collection, target: target, context: context, limit: limit, filter: filter,
            withPayload: withPayload)
    }

    /// Performs multiple discover requests in a single batch.
    public func discoverBatch(
        collection: String,
        requests: [DiscoverRequest]
    ) async throws -> [[ScoredPoint]] {
        try await discover.discoverBatch(collection: collection, requests: requests)
    }

    /// Sets payload values for specific points.
    public func setPayload(
        collection: String,
        ids: [PointID],
        payload: [String: PayloadValue],
        wait: Bool = true
    ) async throws {
        try await self.payload.setPayload(
            collection: collection, ids: ids, payload: payload, wait: wait)
    }

    /// Overwrites the entire payload for specific points.
    public func overwritePayload(
        collection: String,
        ids: [PointID],
        payload: [String: PayloadValue],
        wait: Bool = true
    ) async throws {
        try await self.payload.overwritePayload(
            collection: collection, ids: ids, payload: payload, wait: wait)
    }

    /// Deletes specific payload keys from points.
    public func deletePayload(
        collection: String,
        ids: [PointID],
        keys: [String],
        wait: Bool = true
    ) async throws {
        try await payload.deletePayload(collection: collection, ids: ids, keys: keys, wait: wait)
    }

    /// Clears all payload from points.
    public func clearPayload(
        collection: String,
        ids: [PointID],
        wait: Bool = true
    ) async throws {
        try await payload.clearPayload(collection: collection, ids: ids, wait: wait)
    }

    /// Updates vectors for specific points.
    public func updateVectors(
        collection: String,
        points: [(id: PointID, vector: VectorData)],
        wait: Bool = true
    ) async throws {
        try await vector.updateVectors(collection: collection, points: points, wait: wait)
    }

    /// Deletes specific named vectors from points.
    public func deleteVectors(
        collection: String,
        ids: [PointID],
        vectorNames: [String],
        wait: Bool = true
    ) async throws {
        try await vector.deleteVectors(
            collection: collection, ids: ids, vectorNames: vectorNames, wait: wait)
    }

    /// Creates an index on a payload field.
    public func createFieldIndex(
        collection: String,
        fieldName: String,
        fieldType: FieldType,
        wait: Bool = true
    ) async throws {
        try await index.createFieldIndex(
            collection: collection, fieldName: fieldName, fieldType: fieldType, wait: wait)
    }

    /// Deletes an index on a payload field.
    public func deleteFieldIndex(
        collection: String,
        fieldName: String,
        wait: Bool = true
    ) async throws {
        try await index.deleteFieldIndex(collection: collection, fieldName: fieldName, wait: wait)
    }

    /// Performs faceted search to get value counts.
    public func facet(
        collection: String,
        key: String,
        filter: Filter? = nil,
        limit: UInt64 = 10,
        exact: Bool = false
    ) async throws -> FacetResult {
        try await index.facet(
            collection: collection, key: key, filter: filter, limit: limit, exact: exact)
    }

    /// Performs multiple update operations in a single batch.
    public func updateBatch(
        collection: String,
        operations: [PointsUpdateOperation],
        wait: Bool = true
    ) async throws -> BatchUpdateResult {
        try await batch.updateBatch(collection: collection, operations: operations, wait: wait)
    }
}
