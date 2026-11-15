import Foundation
import QdrantCore
import QdrantProto

extension PointGroup {
    internal init(grpc: Qdrant_PointGroup) {
        self.init(id: GroupId(grpc: grpc.id), hits: grpc.hits.compactMap { ScoredPoint(grpc: $0) })
    }
}

extension GroupId {
    internal init(grpc: Qdrant_GroupId) {
        self =
            switch grpc.kind {
            case .unsignedValue(let value): .unsigned(value)
            case .integerValue(let value): .integer(value)
            case .stringValue(let value): .string(value)
            case .none: .string("")
            }
    }
}

extension QueryInput {
    internal var grpc: Qdrant_Query {
        var query = Qdrant_Query()
        switch self {
        case .nearest(let vector):
            query.nearest = vector.grpc
        case .nearestId(let id):
            var vectorInput = Qdrant_VectorInput()
            vectorInput.id = id.grpc
            query.nearest = vectorInput
        case .nearestWithMmr(let nearest, let mmr):
            var input = Qdrant_NearestInputWithMmr()
            input.nearest = nearest.grpc
            input.mmr = mmr.grpc
            query.nearestWithMmr = input
        case .recommend(let positive, let negative):
            var recommendInput = Qdrant_RecommendInput()
            recommendInput.positive = positive.map { $0.grpc }
            recommendInput.negative = negative.map { $0.grpc }
            query.recommend = recommendInput
        case .discover(let target, let context):
            var discoverInput = Qdrant_DiscoverInput()
            discoverInput.target = target.grpc
            var contextInput = Qdrant_ContextInput()
            contextInput.pairs = context.map { pair in
                var contextPair = Qdrant_ContextInputPair()
                contextPair.positive = pair.positive.grpc
                contextPair.negative = pair.negative.grpc
                return contextPair
            }
            discoverInput.context = contextInput
            query.discover = discoverInput
        case .orderBy(let field, let direction):
            var orderBy = Qdrant_OrderBy()
            orderBy.key = field
            if let direction {
                orderBy.direction = direction.grpc
            }
            query.orderBy = orderBy
        case .fusion(let fusionType):
            query.fusion = fusionType.grpc
        case .rrf(let rrf):
            query.rrf = rrf.grpc
        case .formula(let formula):
            query.formula = formula.grpc
        case .sample(let sampleType):
            query.sample = sampleType.grpc
        case .relevanceFeedback(let feedback):
            query.relevanceFeedback = feedback.grpc
        case .text(let text):
            query.text = text.grpc
        }
        return query
    }
}

extension VectorInput {
    internal var grpc: Qdrant_VectorInput {
        var input = Qdrant_VectorInput()
        switch self {
        case .dense(let vector):
            var dense = Qdrant_DenseVector()
            dense.data = vector
            input.dense = dense
        case .id(let pointId):
            input.id = pointId.grpc
        case .sparse(let indices, let values):
            var sparse = Qdrant_SparseVector()
            sparse.indices = indices
            sparse.values = values
            input.sparse = sparse
        case .multiDense(let vectors):
            var multi = Qdrant_MultiDenseVector()
            multi.vectors = vectors.map { row in
                var dense = Qdrant_DenseVector()
                dense.data = row
                return dense
            }
            input.multiDense = multi
        case .document(let document):
            var message = Qdrant_Document()
            message.text = document.text
            message.model = document.model
            message.options = document.options.mapValues { $0.grpc }
            input.document = message
        case .image(let image):
            var message = Qdrant_Image()
            message.image = image.image.grpc
            message.model = image.model
            message.options = image.options.mapValues { $0.grpc }
            input.image = message
        case .inferenceObject(let object):
            var message = Qdrant_InferenceObject()
            message.object = object.object.grpc
            message.model = object.model
            message.options = object.options.mapValues { $0.grpc }
            input.object = message
        }
        return input
    }
}

extension Mmr {
    internal var grpc: Qdrant_Mmr {
        var message = Qdrant_Mmr()
        if let diversity { message.diversity = diversity }
        if let candidatesLimit { message.candidatesLimit = candidatesLimit }
        return message
    }
}

extension Rrf {
    internal var grpc: Qdrant_Rrf {
        var message = Qdrant_Rrf()
        if let k { message.k = k }
        message.weights = weights
        return message
    }
}

extension FusionType {
    internal var grpc: Qdrant_Fusion {
        switch self {
        case .rrf: .rrf
        case .dbsf: .dbsf
        }
    }
}

extension SampleType {
    internal var grpc: Qdrant_Sample {
        switch self {
        case .random: .random
        }
    }
}

extension OrderDirection {
    internal var grpc: Qdrant_Direction {
        switch self {
        case .ascending: .asc
        case .descending: .desc
        }
    }
}

extension TextQuery {
    internal var grpc: Qdrant_TextQuery {
        var message = Qdrant_TextQuery()
        message.query = query
        if let bm25 { message.bm25 = bm25.grpc }
        return message
    }
}

extension Bm25Params {
    internal var grpc: Qdrant_Bm25Params {
        var message = Qdrant_Bm25Params()
        if let k { message.k = k }
        if let b { message.b = b }
        return message
    }
}

extension IdfParams {
    internal var grpc: Qdrant_IdfParams {
        var message = Qdrant_IdfParams()
        if let corpus { message.corpus = corpus.grpc }
        return message
    }
}

extension RelevanceFeedback {
    internal var grpc: Qdrant_RelevanceFeedbackInput {
        var message = Qdrant_RelevanceFeedbackInput()
        message.target = target.grpc
        message.feedback = feedback.map { item in
            var feedbackItem = Qdrant_FeedbackItem()
            feedbackItem.example = item.example.grpc
            feedbackItem.score = item.score
            return feedbackItem
        }
        var strategy = Qdrant_FeedbackStrategy()
        var naive = Qdrant_NaiveFeedbackStrategy()
        naive.a = self.strategy.a
        naive.b = self.strategy.b
        naive.c = self.strategy.c
        strategy.naive = naive
        message.strategy = strategy
        return message
    }
}

extension Formula {
    internal var grpc: Qdrant_Formula {
        var message = Qdrant_Formula()
        message.expression = expression.grpc
        for (key, value) in defaults {
            message.defaults[key] = value.grpc
        }
        return message
    }
}

extension QdrantCore.Expression {
    internal var grpc: Qdrant_Expression {
        var message = Qdrant_Expression()
        switch self {
        case .constant(let value):
            message.constant = value
        case .variable(let name):
            message.variable = name
        case .condition(let condition):
            message.condition = condition.grpc
        case .geoDistance(let origin, let to):
            var geo = Qdrant_GeoDistance()
            geo.origin = origin.grpc
            geo.to = to
            message.geoDistance = geo
        case .datetime(let value):
            message.datetime = value
        case .datetimeKey(let key):
            message.datetimeKey = key
        case .mult(let terms):
            var mult = Qdrant_MultExpression()
            mult.mult = terms.map { $0.grpc }
            message.mult = mult
        case .sum(let terms):
            var sum = Qdrant_SumExpression()
            sum.sum = terms.map { $0.grpc }
            message.sum = sum
        case .div(let left, let right, let byZeroDefault):
            var div = Qdrant_DivExpression()
            div.left = left.grpc
            div.right = right.grpc
            if let byZeroDefault { div.byZeroDefault = byZeroDefault }
            message.div = div
        case .neg(let value):
            message.neg = value.grpc
        case .abs(let value):
            message.abs = value.grpc
        case .sqrt(let value):
            message.sqrt = value.grpc
        case .pow(let base, let exponent):
            var pow = Qdrant_PowExpression()
            pow.base = base.grpc
            pow.exponent = exponent.grpc
            message.pow = pow
        case .exp(let value):
            message.exp = value.grpc
        case .log10(let value):
            message.log10 = value.grpc
        case .ln(let value):
            message.ln = value.grpc
        case .expDecay(let params):
            message.expDecay = params.grpc
        case .gaussDecay(let params):
            message.gaussDecay = params.grpc
        case .linDecay(let params):
            message.linDecay = params.grpc
        case .acosh(let value):
            message.acosh = value.grpc
        case .max(let terms):
            var max = Qdrant_MaxExpression()
            max.max = terms.map { $0.grpc }
            message.max = max
        case .min(let terms):
            var min = Qdrant_MinExpression()
            min.min = terms.map { $0.grpc }
            message.min = min
        }
        return message
    }
}

extension DecayParams {
    internal var grpc: Qdrant_DecayParamsExpression {
        var message = Qdrant_DecayParamsExpression()
        message.x = x.grpc
        if let target { message.target = target.grpc }
        if let scale { message.scale = scale }
        if let midpoint { message.midpoint = midpoint }
        return message
    }
}

extension PrefetchQuery {
    internal var grpc: Qdrant_PrefetchQuery {
        var prefetchQuery = Qdrant_PrefetchQuery()
        prefetchQuery.prefetch = prefetch.map { $0.grpc }
        if let query { prefetchQuery.query = query.grpc }
        if let using { prefetchQuery.using = using }
        if let filter { prefetchQuery.filter = filter.grpc }
        if let scoreThreshold { prefetchQuery.scoreThreshold = scoreThreshold }
        if let limit { prefetchQuery.limit = limit }
        return prefetchQuery
    }
}

extension Qdrant_SearchParams {
    internal static func idf(_ idf: IdfParams) -> Qdrant_SearchParams {
        var params = Qdrant_SearchParams()
        params.idf = idf.grpc
        return params
    }
}
