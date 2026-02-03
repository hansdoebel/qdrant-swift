import Foundation
import QdrantCore

/// Service for managing points in Qdrant collections via REST API.
public final class PointsService: Sendable {
    private let client: HTTPClient

    internal init(client: HTTPClient) {
        self.client = client
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
        let request = UpsertPointsRequest(points: points)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.put(
            path: "/collections/\(collection)/points",
            body: request,
            queryItems: queryItems
        )
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
        let request = GetPointsRequest(ids: ids, withPayload: withPayload, withVector: withVectors)
        let response: GetPointsResponse = try await client.post(
            path: "/collections/\(collection)/points",
            body: request
        )
        return response.result ?? []
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
        let request = DeletePointsRequest(points: ids)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.post(
            path: "/collections/\(collection)/points/delete",
            body: request,
            queryItems: queryItems
        )
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
        let request = DeletePointsByFilterRequest(filter: filter)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.post(
            path: "/collections/\(collection)/points/delete",
            body: request,
            queryItems: queryItems
        )
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
        limit: Int = 10,
        offset: PointID? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false
    ) async throws -> ScrollResult {
        let request = ScrollRequest(
            filter: filter,
            limit: limit,
            offset: offset,
            withPayload: withPayload,
            withVector: withVectors
        )
        let response: ScrollResponse = try await client.post(
            path: "/collections/\(collection)/points/scroll",
            body: request
        )
        return ScrollResult(
            points: response.result?.points ?? [],
            nextPageOffset: response.result?.nextPageOffset
        )
    }

    /// Counts the number of points in a collection.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - filter: Optional filter to apply.
    ///   - exact: Whether to perform exact count.
    /// - Returns: The number of points.
    public func count(
        collection: String,
        filter: Filter? = nil,
        exact: Bool = true
    ) async throws -> Int {
        let request = CountRequest(filter: filter, exact: exact)
        let response: CountResponse = try await client.post(
            path: "/collections/\(collection)/points/count",
            body: request
        )
        return response.result?.count ?? 0
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
        limit: Int = 10,
        filter: Filter? = nil,
        scoreThreshold: Float? = nil,
        offset: Int? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false,
        vectorName: String? = nil
    ) async throws -> [ScoredPoint] {
        let request = SearchRequestBody(
            vector: vectorName != nil ? .named(vectorName!, vector) : .unnamed(vector),
            filter: filter,
            limit: limit,
            offset: offset,
            withPayload: withPayload,
            withVector: withVectors,
            scoreThreshold: scoreThreshold
        )
        let response: SearchResponse = try await client.post(
            path: "/collections/\(collection)/points/search",
            body: request
        )
        return response.result ?? []
    }

    /// Universal query API.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - query: The query to perform.
    ///   - prefetch: Sub-queries to perform first.
    ///   - using: Vector name to use.
    ///   - filter: Filter conditions.
    ///   - limit: Maximum number of results.
    ///   - offset: Number of results to skip.
    ///   - withPayload: Whether to include payload.
    ///   - withVectors: Whether to include vectors.
    /// - Returns: Array of scored points.
    public func query(
        collection: String,
        query: RestQuery? = nil,
        prefetch: [RestPrefetchQuery]? = nil,
        using: String? = nil,
        filter: Filter? = nil,
        limit: Int = 10,
        offset: Int? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false
    ) async throws -> [ScoredPoint] {
        let request = QueryRequestBody(
            query: query,
            prefetch: prefetch,
            using: using,
            filter: filter,
            limit: limit,
            offset: offset,
            withPayload: withPayload,
            withVector: withVectors
        )
        let response: QueryResponse = try await client.post(
            path: "/collections/\(collection)/points/query",
            body: request
        )
        return response.result?.points ?? []
    }

    /// Finds points similar to positive examples.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - positive: Point IDs to use as positive examples.
    ///   - negative: Point IDs to use as negative examples.
    ///   - limit: Maximum number of results.
    ///   - filter: Optional filter to apply.
    ///   - withPayload: Whether to include payload.
    ///   - withVectors: Whether to include vectors.
    /// - Returns: An array of scored points.
    public func recommend(
        collection: String,
        positive: [PointID],
        negative: [PointID] = [],
        limit: Int = 10,
        filter: Filter? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false
    ) async throws -> [ScoredPoint] {
        let request = RecommendRequestBody(
            positive: positive,
            negative: negative,
            filter: filter,
            limit: limit,
            withPayload: withPayload,
            withVector: withVectors
        )
        let response: SearchResponse = try await client.post(
            path: "/collections/\(collection)/points/recommend",
            body: request
        )
        return response.result ?? []
    }

    /// Sets payload values for specific points.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - ids: The point IDs to update.
    ///   - payload: The payload values to set.
    ///   - wait: Whether to wait for the operation to complete.
    public func setPayload(
        collection: String,
        ids: [PointID],
        payload: [String: PayloadValue],
        wait: Bool = true
    ) async throws {
        let request = SetPayloadRequest(payload: payload, points: ids)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.post(
            path: "/collections/\(collection)/points/payload",
            body: request,
            queryItems: queryItems
        )
    }

    /// Deletes specific payload keys from points.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - ids: The point IDs to update.
    ///   - keys: The payload keys to delete.
    ///   - wait: Whether to wait for the operation to complete.
    public func deletePayload(
        collection: String,
        ids: [PointID],
        keys: [String],
        wait: Bool = true
    ) async throws {
        let request = DeletePayloadRequest(keys: keys, points: ids)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.post(
            path: "/collections/\(collection)/points/payload/delete",
            body: request,
            queryItems: queryItems
        )
    }

    /// Clears all payload from points.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - ids: The point IDs to clear payload from.
    ///   - wait: Whether to wait for the operation to complete.
    public func clearPayload(
        collection: String,
        ids: [PointID],
        wait: Bool = true
    ) async throws {
        let request = ClearPayloadRequest(points: ids)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.post(
            path: "/collections/\(collection)/points/payload/clear",
            body: request,
            queryItems: queryItems
        )
    }

    /// Overwrites the entire payload for specific points.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - ids: The point IDs to update.
    ///   - payload: The payload to set (replaces existing).
    ///   - wait: Whether to wait for the operation to complete.
    public func overwritePayload(
        collection: String,
        ids: [PointID],
        payload: [String: PayloadValue],
        wait: Bool = true
    ) async throws {
        let request = OverwritePayloadRequest(payload: payload, points: ids)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.put(
            path: "/collections/\(collection)/points/payload",
            body: request,
            queryItems: queryItems
        )
    }

    /// Updates vectors for existing points.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - points: The point vector updates.
    ///   - wait: Whether to wait for the operation to complete.
    public func updateVectors(
        collection: String,
        points: [PointVectorUpdate],
        wait: Bool = true
    ) async throws {
        let request = UpdateVectorsRequest(points: points)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.put(
            path: "/collections/\(collection)/points/vectors",
            body: request,
            queryItems: queryItems
        )
    }

    /// Deletes vectors from existing points.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - ids: The point IDs.
    ///   - vectors: The vector names to delete.
    ///   - wait: Whether to wait for the operation to complete.
    public func deleteVectors(
        collection: String,
        ids: [PointID],
        vectors: [String],
        wait: Bool = true
    ) async throws {
        let request = DeleteVectorsRequest(points: ids, vectors: vectors)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.post(
            path: "/collections/\(collection)/points/vectors/delete",
            body: request,
            queryItems: queryItems
        )
    }

    /// Performs multiple search requests in a batch.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - searches: The search queries to perform.
    /// - Returns: Array of search results for each query.
    public func searchBatch(
        collection: String,
        searches: [SearchBatchQuery]
    ) async throws -> [[ScoredPoint]] {
        let request = SearchBatchRequest(searches: searches)
        let response: SearchBatchResponse = try await client.post(
            path: "/collections/\(collection)/points/search/batch",
            body: request
        )
        return response.result ?? []
    }

    /// Performs multiple query requests in a batch.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - queries: The queries to perform.
    /// - Returns: Array of query results for each query.
    public func queryBatch(
        collection: String,
        queries: [QueryBatchQuery]
    ) async throws -> [[ScoredPoint]] {
        let request = QueryBatchRequest(searches: queries)
        let response: QueryBatchResponse = try await client.post(
            path: "/collections/\(collection)/points/query/batch",
            body: request
        )
        return response.result?.map { $0.points } ?? []
    }

    /// Performs multiple recommend requests in a batch.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - recommends: The recommend queries to perform.
    /// - Returns: Array of recommend results for each query.
    public func recommendBatch(
        collection: String,
        recommends: [RecommendBatchQuery]
    ) async throws -> [[ScoredPoint]] {
        let request = RecommendBatchRequest(searches: recommends)
        let response: RecommendBatchResponse = try await client.post(
            path: "/collections/\(collection)/points/recommend/batch",
            body: request
        )
        return response.result ?? []
    }

    /// Applies a series of update operations in a batch.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - operations: The operations to perform.
    ///   - wait: Whether to wait for the operation to complete.
    /// - Returns: Array of operation results.
    public func updateBatch(
        collection: String,
        operations: [RestPointsUpdateOperation],
        wait: Bool = true
    ) async throws -> [UpdateResult] {
        let request = UpdateBatchRequest(operations: operations)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let response: UpdateBatchResponse = try await client.post(
            path: "/collections/\(collection)/points/batch",
            body: request,
            queryItems: queryItems
        )
        return response.result ?? []
    }

    /// Searches for similar vectors, grouping results by a payload field.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - vector: The query vector.
    ///   - groupBy: The payload field to group by.
    ///   - groupSize: Maximum number of results per group.
    ///   - limit: Maximum number of groups.
    ///   - filter: Optional filter to apply.
    ///   - scoreThreshold: Minimum score threshold.
    ///   - withPayload: Whether to include payload.
    ///   - withVectors: Whether to include vectors.
    ///   - vectorName: Name of the vector field (for multi-vector collections).
    /// - Returns: Grouped search results.
    public func searchGroups(
        collection: String,
        vector: [Float],
        groupBy: String,
        groupSize: Int = 1,
        limit: Int = 10,
        filter: Filter? = nil,
        scoreThreshold: Float? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false,
        vectorName: String? = nil
    ) async throws -> RestSearchGroupsResult {
        let request = SearchGroupsRequest(
            vector: vectorName != nil ? .named(vectorName!, vector) : .unnamed(vector),
            groupBy: groupBy,
            groupSize: groupSize,
            limit: limit,
            filter: filter,
            scoreThreshold: scoreThreshold,
            withPayload: withPayload,
            withVector: withVectors
        )
        let response: SearchGroupsResponse = try await client.post(
            path: "/collections/\(collection)/points/search/groups",
            body: request
        )
        return response.result ?? RestSearchGroupsResult(groups: [])
    }

    /// Queries points, grouping results by a payload field.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - query: The query to perform.
    ///   - groupBy: The payload field to group by.
    ///   - groupSize: Maximum number of results per group.
    ///   - limit: Maximum number of groups.
    ///   - filter: Optional filter to apply.
    ///   - withPayload: Whether to include payload.
    ///   - withVectors: Whether to include vectors.
    /// - Returns: Grouped query results.
    public func queryGroups(
        collection: String,
        query: RestQuery? = nil,
        groupBy: String,
        groupSize: Int = 1,
        limit: Int = 10,
        filter: Filter? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false
    ) async throws -> RestSearchGroupsResult {
        let request = QueryGroupsRequest(
            query: query,
            groupBy: groupBy,
            groupSize: groupSize,
            limit: limit,
            filter: filter,
            withPayload: withPayload,
            withVector: withVectors
        )
        let response: QueryGroupsResponse = try await client.post(
            path: "/collections/\(collection)/points/query/groups",
            body: request
        )
        return response.result ?? RestSearchGroupsResult(groups: [])
    }

    /// Recommends points, grouping results by a payload field.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - positive: Point IDs to use as positive examples.
    ///   - negative: Point IDs to use as negative examples.
    ///   - groupBy: The payload field to group by.
    ///   - groupSize: Maximum number of results per group.
    ///   - limit: Maximum number of groups.
    ///   - filter: Optional filter to apply.
    ///   - withPayload: Whether to include payload.
    ///   - withVectors: Whether to include vectors.
    /// - Returns: Grouped recommend results.
    public func recommendGroups(
        collection: String,
        positive: [PointID],
        negative: [PointID] = [],
        groupBy: String,
        groupSize: Int = 1,
        limit: Int = 10,
        filter: Filter? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false
    ) async throws -> RestSearchGroupsResult {
        let request = RecommendGroupsRequest(
            positive: positive,
            negative: negative,
            groupBy: groupBy,
            groupSize: groupSize,
            limit: limit,
            filter: filter,
            withPayload: withPayload,
            withVector: withVectors
        )
        let response: RecommendGroupsResponse = try await client.post(
            path: "/collections/\(collection)/points/recommend/groups",
            body: request
        )
        return response.result ?? RestSearchGroupsResult(groups: [])
    }

    /// Discovers points using context pairs to guide the search.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - target: The target to find similar points to.
    ///   - context: Context pairs to guide discovery.
    ///   - limit: Maximum number of results.
    ///   - filter: Optional filter to apply.
    ///   - withPayload: Whether to include payload.
    ///   - withVectors: Whether to include vectors.
    /// - Returns: An array of scored points.
    public func discover(
        collection: String,
        target: RestDiscoverTarget? = nil,
        context: [RestContextPair]? = nil,
        limit: Int = 10,
        filter: Filter? = nil,
        withPayload: Bool = true,
        withVectors: Bool = false
    ) async throws -> [ScoredPoint] {
        let request = DiscoverRequest(
            target: target,
            context: context,
            filter: filter,
            limit: limit,
            withPayload: withPayload,
            withVector: withVectors
        )
        let response: DiscoverResponse = try await client.post(
            path: "/collections/\(collection)/points/discover",
            body: request
        )
        return response.result ?? []
    }

    /// Performs multiple discover requests in a batch.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - discovers: The discover queries to perform.
    /// - Returns: Array of discover results for each query.
    public func discoverBatch(
        collection: String,
        discovers: [DiscoverBatchQuery]
    ) async throws -> [[ScoredPoint]] {
        let request = DiscoverBatchRequest(searches: discovers)
        let response: DiscoverBatchResponse = try await client.post(
            path: "/collections/\(collection)/points/discover/batch",
            body: request
        )
        return response.result ?? []
    }

    /// Computes similarity matrix between pairs of points.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - sample: Number of points to sample.
    ///   - limit: Maximum number of pairs to return.
    ///   - filter: Optional filter to apply.
    /// - Returns: Similarity pairs result.
    public func searchMatrixPairs(
        collection: String,
        sample: Int = 10,
        limit: Int = 10,
        filter: Filter? = nil
    ) async throws -> RestSearchMatrixPairsResult {
        let request = SearchMatrixRequest(sample: sample, limit: limit, filter: filter)
        let response: SearchMatrixPairsResponse = try await client.post(
            path: "/collections/\(collection)/points/search/matrix/pairs",
            body: request
        )
        return response.result ?? RestSearchMatrixPairsResult(pairs: [])
    }

    /// Computes similarity matrix as offsets.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - sample: Number of points to sample.
    ///   - limit: Maximum number of pairs to return.
    ///   - filter: Optional filter to apply.
    /// - Returns: Similarity offsets result.
    public func searchMatrixOffsets(
        collection: String,
        sample: Int = 10,
        limit: Int = 10,
        filter: Filter? = nil
    ) async throws -> RestSearchMatrixOffsetsResult {
        let request = SearchMatrixRequest(sample: sample, limit: limit, filter: filter)
        let response: SearchMatrixOffsetsResponse = try await client.post(
            path: "/collections/\(collection)/points/search/matrix/offsets",
            body: request
        )
        return response.result
            ?? RestSearchMatrixOffsetsResult(ids: [], offsetsRow: [], offsetsCol: [], scores: [])
    }

    /// Gets facet counts for a payload field.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - key: The payload field to facet on.
    ///   - limit: Maximum number of facet values to return.
    ///   - filter: Optional filter to apply.
    ///   - exact: Whether to perform exact count.
    /// - Returns: Facet results.
    public func facet(
        collection: String,
        key: String,
        limit: Int = 10,
        filter: Filter? = nil,
        exact: Bool = false
    ) async throws -> RestFacetResult {
        let request = FacetRequest(key: key, limit: limit, filter: filter, exact: exact)
        let response: FacetResponse = try await client.post(
            path: "/collections/\(collection)/facet",
            body: request
        )
        return response.result ?? RestFacetResult(hits: [])
    }

    /// Creates an index on a payload field.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - fieldName: The field name to index.
    ///   - fieldType: The field type for the index.
    ///   - wait: Whether to wait for the operation to complete.
    public func createFieldIndex(
        collection: String,
        fieldName: String,
        fieldType: FieldType,
        wait: Bool = true
    ) async throws {
        let request = CreateFieldIndexRequest(fieldName: fieldName, fieldSchema: fieldType)
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.put(
            path: "/collections/\(collection)/index",
            body: request,
            queryItems: queryItems
        )
    }

    /// Deletes an index on a payload field.
    /// - Parameters:
    ///   - collection: The collection name.
    ///   - fieldName: The field name to remove index from.
    ///   - wait: Whether to wait for the operation to complete.
    public func deleteFieldIndex(
        collection: String,
        fieldName: String,
        wait: Bool = true
    ) async throws {
        let queryItems = [URLQueryItem(name: "wait", value: wait ? "true" : "false")]
        let _: PointsOperationResponse = try await client.delete(
            path: "/collections/\(collection)/index/\(fieldName)",
            queryItems: queryItems
        )
    }
}

struct UpsertPointsRequest: Encodable {
    let points: [Point]
}

struct GetPointsRequest: Encodable {
    let ids: [PointID]
    let withPayload: Bool
    let withVector: Bool
}

struct DeletePointsRequest: Encodable {
    let points: [PointID]
}

struct DeletePointsByFilterRequest: Encodable {
    let filter: Filter
}

struct ScrollRequest: Encodable {
    let filter: Filter?
    let limit: Int
    let offset: PointID?
    let withPayload: Bool
    let withVector: Bool
}

struct CountRequest: Encodable {
    let filter: Filter?
    let exact: Bool
}

struct SearchRequestBody: Encodable {
    let vector: RestVectorQuery
    let filter: Filter?
    let limit: Int
    let offset: Int?
    let withPayload: Bool
    let withVector: Bool
    let scoreThreshold: Float?
}

struct QueryRequestBody: Encodable {
    let query: RestQuery?
    let prefetch: [RestPrefetchQuery]?
    let using: String?
    let filter: Filter?
    let limit: Int
    let offset: Int?
    let withPayload: Bool
    let withVector: Bool
}

struct RecommendRequestBody: Encodable {
    let positive: [PointID]
    let negative: [PointID]
    let filter: Filter?
    let limit: Int
    let withPayload: Bool
    let withVector: Bool
}

struct SetPayloadRequest: Encodable {
    let payload: [String: PayloadValue]
    let points: [PointID]
}

struct DeletePayloadRequest: Encodable {
    let keys: [String]
    let points: [PointID]
}

struct ClearPayloadRequest: Encodable {
    let points: [PointID]
}

struct CreateFieldIndexRequest: Encodable {
    let fieldName: String
    let fieldSchema: FieldType
}

struct OverwritePayloadRequest: Encodable {
    let payload: [String: PayloadValue]
    let points: [PointID]
}

struct UpdateVectorsRequest: Encodable {
    let points: [PointVectorUpdate]
}

struct DeleteVectorsRequest: Encodable {
    let points: [PointID]
    let vectors: [String]
}

struct SearchBatchRequest: Encodable {
    let searches: [SearchBatchQuery]
}

struct QueryBatchRequest: Encodable {
    let searches: [QueryBatchQuery]
}

struct RecommendBatchRequest: Encodable {
    let searches: [RecommendBatchQuery]
}

struct DiscoverBatchRequest: Encodable {
    let searches: [DiscoverBatchQuery]
}

struct UpdateBatchRequest: Encodable {
    let operations: [RestPointsUpdateOperation]
}

struct SearchGroupsRequest: Encodable {
    let vector: RestVectorQuery
    let groupBy: String
    let groupSize: Int
    let limit: Int
    let filter: Filter?
    let scoreThreshold: Float?
    let withPayload: Bool
    let withVector: Bool
}

struct QueryGroupsRequest: Encodable {
    let query: RestQuery?
    let groupBy: String
    let groupSize: Int
    let limit: Int
    let filter: Filter?
    let withPayload: Bool
    let withVector: Bool
}

struct RecommendGroupsRequest: Encodable {
    let positive: [PointID]
    let negative: [PointID]
    let groupBy: String
    let groupSize: Int
    let limit: Int
    let filter: Filter?
    let withPayload: Bool
    let withVector: Bool
}

struct DiscoverRequest: Encodable {
    let target: RestDiscoverTarget?
    let context: [RestContextPair]?
    let filter: Filter?
    let limit: Int
    let withPayload: Bool
    let withVector: Bool
}

struct SearchMatrixRequest: Encodable {
    let sample: Int
    let limit: Int
    let filter: Filter?
}

struct FacetRequest: Encodable {
    let key: String
    let limit: Int
    let filter: Filter?
    let exact: Bool
}

struct GetPointsResponse: Codable {
    let result: [RetrievedPoint]?
}

struct ScrollResponse: Codable {
    let result: ScrollResultResponse?

    struct ScrollResultResponse: Codable {
        let points: [RetrievedPoint]
        let nextPageOffset: PointID?
    }
}

struct CountResponse: Codable {
    let result: CountResult?

    struct CountResult: Codable {
        let count: Int
    }
}

struct SearchResponse: Codable {
    let result: [ScoredPoint]?
}

struct QueryResult: Codable {
    let points: [ScoredPoint]
}

struct QueryResponse: Codable {
    let result: QueryResult?
}

struct SearchBatchResponse: Codable {
    let result: [[ScoredPoint]]?
}

struct QueryBatchResponse: Codable {
    let result: [QueryResult]?
}

struct RecommendBatchResponse: Codable {
    let result: [[ScoredPoint]]?
}

struct DiscoverBatchResponse: Codable {
    let result: [[ScoredPoint]]?
}

struct UpdateBatchResponse: Codable {
    let result: [UpdateResult]?
}

struct SearchGroupsResponse: Codable {
    let result: RestSearchGroupsResult?
}

struct QueryGroupsResponse: Codable {
    let result: RestSearchGroupsResult?
}

struct RecommendGroupsResponse: Codable {
    let result: RestSearchGroupsResult?
}

struct DiscoverResponse: Codable {
    let result: [ScoredPoint]?
}

struct SearchMatrixPairsResponse: Codable {
    let result: RestSearchMatrixPairsResult?
}

struct SearchMatrixOffsetsResponse: Codable {
    let result: RestSearchMatrixOffsetsResult?
}

struct FacetResponse: Codable {
    let result: RestFacetResult?
}

/// Response for points mutation operations (upsert, delete, payload ops, etc.)
/// Returns an UpdateResult with operation_id and status, not a simple boolean.
struct PointsOperationResponse: Codable {
    let result: PointsOperationResult?
    let status: String?

    struct PointsOperationResult: Codable {
        let operationId: UInt64?
        let status: String?
    }
}
