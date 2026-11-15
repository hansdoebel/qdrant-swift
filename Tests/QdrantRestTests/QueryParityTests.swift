import Testing

@testable import QdrantCore
@testable import QdrantREST

@Suite("Query API REST encoding")
struct RestQueryParityTests {
    @Test("MMR, DBSF, weighted RRF, and BM25 text encode with the REST field names")
    func queryObjects() throws {
        let mmr = try jsonObject(
            QueryInput.nearestWithMmr(
                nearest: .sparse(indices: [3], values: [1]),
                mmr: Mmr(diversity: 0.4, candidatesLimit: 8)
            )
        )
        #expect(mmr["nearest"] as? [String: Any] != nil)
        let mmrBody = mmr["mmr"] as? [String: Any]
        #expect(mmrBody?["diversity"] as? Float == 0.4 || (mmrBody?["diversity"] as? Double) == 0.4)
        #expect(mmrBody?["candidates_limit"] as? Int == 8 || (mmrBody?["candidates_limit"] as? UInt32) == 8)

        let dbsf = try jsonObject(QueryInput.fusion(.dbsf))
        #expect(dbsf["fusion"] as? String == "dbsf")

        let rrf = try jsonObject(QueryInput.rrf(Rrf(k: 10, weights: [2, 1])))
        let rrfBody = rrf["rrf"] as? [String: Any]
        #expect(rrfBody?["k"] as? Int == 10 || (rrfBody?["k"] as? UInt32) == 10)
        #expect((rrfBody?["weights"] as? [Double])?.count == 2 || (rrfBody?["weights"] as? [Float])?.count == 2)

        let text = try jsonObject(QueryInput.text(TextQuery(query: "time travel", bm25: Bm25Params(k: 1.2, b: 0.75))))
        let textBody = text["text"] as? [String: Any]
        #expect(textBody?["query"] as? String == "time travel")
        let bm25 = textBody?["bm25"] as? [String: Any]
        #expect(bm25?["k"] != nil)
        #expect(bm25?["b"] != nil)
    }

    @Test("Formula JSON uses acosh, max, and min")
    func formula() throws {
        let encoded = try jsonObject(
            QueryInput.formula(
                Formula(
                    expression: .sum([
                        .acosh(.variable("$score")),
                        .max([.constant(1)]),
                        .min([.variable("floor")]),
                    ]),
                    defaults: ["floor": .double(0)]
                )
            )
        )
        let formula = encoded["formula"] as? [String: Any]
        let sum = formula?["sum"] as? [Any]
        #expect(sum?.count == 3)
        #expect((sum?[0] as? [String: Any])?["acosh"] as? String == "$score")
        #expect((sum?[1] as? [String: Any])?["max"] != nil)
        #expect((sum?[2] as? [String: Any])?["min"] != nil)
        #expect(encoded["defaults"] != nil)
    }

    @Test("Document, image, and inference object use their REST fields")
    func inferenceVectors() throws {
        let document = try jsonObject(VectorInput.document(Document(text: "hello", model: "qdrant/bm25")))
        #expect(document["text"] as? String == "hello")
        #expect(document["model"] as? String == "qdrant/bm25")

        let image = try jsonObject(
            VectorInput.image(QueryImage(image: .string("https://example.test/a.png"), model: "clip"))
        )
        #expect(image["image"] as? String == "https://example.test/a.png")
        #expect(image["model"] as? String == "clip")

        let object = try jsonObject(
            VectorInput.inferenceObject(InferenceObject(object: .string("sku-1"), model: "custom"))
        )
        #expect(object["object"] as? String == "sku-1")
        #expect(object["model"] as? String == "custom")
    }

    @Test("Prefetch nesting and relevance feedback encode")
    func prefetchAndFeedback() throws {
        let prefetch = try jsonObject(
            PrefetchQuery(
                prefetch: [PrefetchQuery(query: .text(TextQuery(query: "nested")), using: "body")],
                query: .relevanceFeedback(
                    RelevanceFeedback(
                        target: .id(.integer(1)),
                        feedback: [FeedbackItem(example: .dense([1, 0]), score: 0.2)],
                        strategy: NaiveFeedbackStrategy(a: 1, b: 2, c: 3)
                    )
                )
            )
        )
        let nested = (prefetch["prefetch"] as? [[String: Any]])?.first
        #expect(nested?["using"] as? String == "body")
        let feedback = (prefetch["query"] as? [String: Any])?["relevance_feedback"] as? [String: Any]
        let strategy = feedback?["strategy"] as? [String: Any]
        #expect((strategy?["naive"] as? [String: Any])?["b"] != nil)
    }

    @Test("Query JSON round-trips recommend, discover, order, document, and expressions")
    func roundTrips() throws {
        let document = try roundTrip(
            QueryInput.nearest(.document(Document(text: "hello", model: "qdrant/bm25", options: ["lang": "en"])))
        )
        if case .nearest(.document(let value)) = document {
            #expect(value.text == "hello")
            #expect(value.model == "qdrant/bm25")
            #expect(value.options["lang"] == .string("en"))
        } else {
            Issue.record("Expected a document query")
        }

        let image = try roundTrip(
            VectorInput.image(QueryImage(image: .string("https://example.test/a.png"), model: "clip", options: ["size": "large"]))
        )
        if case .image(let value) = image {
            #expect(value.model == "clip")
            #expect(value.options["size"] == .string("large"))
        } else {
            Issue.record("Expected an image query")
        }

        let object = try roundTrip(
            VectorInput.inferenceObject(InferenceObject(object: .string("sku-1"), model: "custom", options: ["lang": "en"]))
        )
        if case .inferenceObject(let value) = object {
            #expect(value.options["lang"] == .string("en"))
        } else {
            Issue.record("Expected an inference object")
        }

        let recommend = try roundTrip(QueryInput.recommend(positive: [.dense([1])], negative: [.id(.integer(2))]))
        if case .recommend(let positive, let negative) = recommend {
            #expect(positive.count == 1)
            #expect(negative.count == 1)
        } else {
            Issue.record("Expected recommend")
        }

        let discover = try roundTrip(
            QueryInput.discover(
                target: .dense([1]),
                context: [ContextInputPair(positive: .dense([1]), negative: .dense([0]))]
            )
        )
        if case .discover(_, let context) = discover {
            #expect(context.count == 1)
        } else {
            Issue.record("Expected discover")
        }

        let ordered = try roundTrip(QueryInput.orderBy(field: "price", direction: .descending))
        if case .orderBy(let field, let direction) = ordered {
            #expect(field == "price")
            if case .descending = direction {} else { Issue.record("Expected descending") }
        } else {
            Issue.record("Expected order_by")
        }

        let negative = try roundTrip(QdrantCore.Expression.neg(.constant(1)))
        if case .neg(.constant) = negative {} else { Issue.record("Expected neg") }
        let power = try roundTrip(QdrantCore.Expression.pow(base: .constant(2), exponent: .constant(3)))
        if case .pow = power {} else { Issue.record("Expected pow") }
    }

    @Test("Grouped and batch text queries send using")
    func textQueryField() throws {
        let batch = try jsonObject(QueryBatchQuery(query: .text(TextQuery(query: "hello")), using: "body"))
        #expect(batch["using"] as? String == "body")
        let groups = try jsonObject(
            QueryGroupsRequest(
                query: .text(TextQuery(query: "hello")),
                groupBy: "lang",
                groupSize: 2,
                limit: 3,
                filter: nil,
                withPayload: true,
                withVector: false,
                params: nil,
                using: "body"
            ),
            snakeCase: true
        )
        #expect(groups["using"] as? String == "body")
        #expect(groups["group_by"] as? String == "lang")
    }
}
