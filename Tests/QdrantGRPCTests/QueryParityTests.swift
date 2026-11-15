import Testing

@testable import QdrantCore
@testable import QdrantGRPC
@testable import QdrantMocks
import QdrantProto

@Suite("Query API gRPC mapping")
struct QueryParityTests {
    @Test("MMR nearest query maps onto nearest_with_mmr")
    func mmr() {
        let query = QueryInput.nearestWithMmr(
            nearest: [0.25, 0.5],
            mmr: Mmr(diversity: 0.7, candidatesLimit: 20)
        )
        guard case .nearestWithMmr(let value) = query.grpc.variant else {
            Issue.record("Expected nearest_with_mmr")
            return
        }
        #expect(value.nearest.dense.data == [0.25, 0.5])
        #expect(value.mmr.diversity == 0.7)
        #expect(value.mmr.candidatesLimit == 20)
    }

    @Test("Formula rescoring includes acosh, max, and min")
    func formula() {
        let expression = Expression.sum([
            .acosh(.variable("$score")),
            .max([.constant(1), .variable("boost")]),
            .min([.constant(0), .variable("penalty")]),
        ])
        let query = QueryInput.formula(Formula(expression: expression, defaults: ["boost": .double(2)]))
        guard case .formula(let formula) = query.grpc.variant else {
            Issue.record("Expected formula")
            return
        }
        guard case .sum(let sum) = formula.expression.variant else {
            Issue.record("Expected sum")
            return
        }
        #expect(sum.sum.count == 3)
        if case .acosh = sum.sum[0].variant {} else { Issue.record("Expected acosh") }
        if case .max = sum.sum[1].variant {} else { Issue.record("Expected max") }
        if case .min = sum.sum[2].variant {} else { Issue.record("Expected min") }
        #expect(formula.defaults["boost"]?.doubleValue == 2)
    }

    @Test("Parameterized RRF carries k and weights, and DBSF is a fusion")
    func fusion() {
        let rrf = QueryInput.rrf(Rrf(k: 60, weights: [1, 0.25]))
        guard case .rrf(let value) = rrf.grpc.variant else {
            Issue.record("Expected rrf")
            return
        }
        #expect(value.k == 60)
        #expect(value.weights == [1, 0.25])

        let dbsf = QueryInput.fusion(.dbsf)
        guard case .fusion(let fusion) = dbsf.grpc.variant else {
            Issue.record("Expected fusion")
            return
        }
        #expect(fusion == .dbsf)
    }

    @Test("Vector input covers sparse, multi-dense, document, image, and object")
    func vectorInputs() {
        let sparse = VectorInput.sparse(indices: [1, 4], values: [0.5, 0.2]).grpc
        #expect(sparse.sparse.indices == [1, 4])
        #expect(sparse.sparse.values == [0.5, 0.2])

        let multi = VectorInput.multiDense([[0.1, 0.2], [0.3, 0.4]]).grpc
        #expect(multi.multiDense.vectors.map(\.data) == [[0.1, 0.2], [0.3, 0.4]])

        let document = VectorInput.document(Document(text: "hello", model: "qdrant/bm25")).grpc
        #expect(document.document.text == "hello")
        #expect(document.document.model == "qdrant/bm25")

        let image = VectorInput.image(QueryImage(image: .string("https://example.test/a.png"), model: "clip")).grpc
        #expect(image.image.image.stringValue == "https://example.test/a.png")
        #expect(image.image.model == "clip")

        let object = VectorInput.inferenceObject(
            InferenceObject(object: .object(["color": .string("red")]), model: "custom")
        ).grpc
        #expect(object.object.model == "custom")
        #expect(object.object.object.structValue.fields["color"]?.stringValue == "red")
    }

    @Test("Text query carries BM25 parameters and relevance feedback")
    func textAndFeedback() {
        let text = QueryInput.text(TextQuery(query: "time travel", bm25: Bm25Params(k: 1.4, b: 0.6)))
        guard case .text(let value) = text.grpc.variant else {
            Issue.record("Expected text")
            return
        }
        #expect(value.query == "time travel")
        #expect(value.bm25.k == 1.4)
        #expect(value.bm25.b == 0.6)

        let feedback = QueryInput.relevanceFeedback(
            RelevanceFeedback(
                target: .dense([1, 0]),
                feedback: [FeedbackItem(example: .id(.integer(7)), score: 0.9)],
                strategy: NaiveFeedbackStrategy(a: 0.5, b: 1, c: 0.2)
            )
        )
        guard case .relevanceFeedback(let value) = feedback.grpc.variant else {
            Issue.record("Expected relevance feedback")
            return
        }
        #expect(value.feedback.count == 1)
        #expect(value.feedback[0].score == 0.9)
        #expect(value.strategy.naive.a == 0.5)
        #expect(value.strategy.naive.c == 0.2)
    }

    @Test("IDF corpus and nested prefetch are preserved")
    func idfAndPrefetch() {
        let corpus = Filter(must: [.field(key: "lang", match: .exact("en"))])
        let params = Qdrant_SearchParams.idf(IdfParams(corpus: corpus))
        #expect(params.idf.corpus.must.count == 1)

        let nested = PrefetchQuery(
            prefetch: [PrefetchQuery(query: .nearest([1, 0]), limit: 5)],
            query: .fusion(.rrf),
            using: "dense"
        )
        #expect(nested.grpc.prefetch.count == 1)
        #expect(nested.grpc.prefetch[0].limit == 5)
        #expect(nested.grpc.using == "dense")
        if case .fusion = nested.grpc.query.variant {} else {
            Issue.record("Expected nested fusion query")
        }
    }

    @Test("Mock points service records query, query batch, and query groups")
    func mockCoversQuery() async throws {
        let mock = MockPointsService()
        let query = QueryInput.text(TextQuery(query: "qdrant"))
        _ = try await mock.query(
            collection: "books",
            query: query,
            prefetch: [PrefetchQuery(query: .nearest([1, 0]))],
            using: "title",
            filter: nil,
            limit: 3,
            offset: nil,
            scoreThreshold: nil,
            withPayload: true,
            withVectors: false,
            idf: IdfParams()
        )
        _ = try await mock.queryBatch(collection: "books", queries: [QueryRequest(query: query)])
        _ = try await mock.queryGroups(
            collection: "books",
            query: query,
            groupBy: "author",
            limit: 2,
            groupSize: 1,
            prefetch: [],
            using: "title",
            filter: nil,
            scoreThreshold: nil,
            withPayload: true,
            idf: nil
        )
        #expect(mock.queryCallCount == 1)
        #expect(mock.queryBatchCallCount == 1)
        #expect(mock.queryGroupsCallCount == 1)
        #expect(mock.queryCalls.count == 3)
        #expect(mock.queryCalls[0].using == "title")
    }
}
