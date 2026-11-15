import Foundation
import Testing

@testable import QdrantCore
@testable import QdrantREST

@Suite("Query API REST encoding")
struct RestQueryParityTests {
    @Test("MMR, DBSF, weighted RRF, and BM25 text encode with the REST field names")
    func queryObjects() throws {
        let mmr = try json(
            QueryInput.nearestWithMmr(
                nearest: .sparse(indices: [3], values: [1]),
                mmr: Mmr(diversity: 0.4, candidatesLimit: 8)
            )
        )
        #expect(mmr["nearest"] as? [String: Any] != nil)
        let mmrBody = mmr["mmr"] as? [String: Any]
        #expect(mmrBody?["diversity"] as? Float == 0.4 || (mmrBody?["diversity"] as? Double) == 0.4)
        #expect(mmrBody?["candidates_limit"] as? Int == 8 || (mmrBody?["candidates_limit"] as? UInt32) == 8)

        let dbsf = try json(QueryInput.fusion(.dbsf))
        #expect(dbsf["fusion"] as? String == "dbsf")

        let rrf = try json(QueryInput.rrf(Rrf(k: 10, weights: [2, 1])))
        let rrfBody = rrf["rrf"] as? [String: Any]
        #expect(rrfBody?["k"] as? Int == 10 || (rrfBody?["k"] as? UInt32) == 10)
        #expect((rrfBody?["weights"] as? [Double])?.count == 2 || (rrfBody?["weights"] as? [Float])?.count == 2)

        let text = try json(QueryInput.text(TextQuery(query: "time travel", bm25: Bm25Params(k: 1.2, b: 0.75))))
        let textBody = text["text"] as? [String: Any]
        #expect(textBody?["query"] as? String == "time travel")
        let bm25 = textBody?["bm25"] as? [String: Any]
        #expect(bm25?["k"] != nil)
        #expect(bm25?["b"] != nil)
    }

    @Test("Formula JSON uses acosh, max, and min")
    func formula() throws {
        let encoded = try json(
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
        let document = try json(VectorInput.document(Document(text: "hello", model: "qdrant/bm25")))
        #expect(document["text"] as? String == "hello")
        #expect(document["model"] as? String == "qdrant/bm25")

        let image = try json(
            VectorInput.image(QueryImage(image: .string("https://example.test/a.png"), model: "clip"))
        )
        #expect(image["image"] as? String == "https://example.test/a.png")
        #expect(image["model"] as? String == "clip")

        let object = try json(
            VectorInput.inferenceObject(InferenceObject(object: .string("sku-1"), model: "custom"))
        )
        #expect(object["object"] as? String == "sku-1")
        #expect(object["model"] as? String == "custom")
    }

    @Test("Prefetch nesting and relevance feedback encode")
    func prefetchAndFeedback() throws {
        let prefetch = try json(
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

    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }
}
