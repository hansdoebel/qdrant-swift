import Foundation
import QdrantCore
import QdrantProto

public typealias PointID = QdrantCore.PointID
public typealias VectorData = QdrantCore.VectorData
public typealias Point = QdrantCore.Point
public typealias ScoredPoint = QdrantCore.ScoredPoint
public typealias RetrievedPoint = QdrantCore.RetrievedPoint
public typealias ScrollResult = QdrantCore.ScrollResult

extension PointID {
    internal var grpc: Qdrant_PointId {
        var id = Qdrant_PointId()
        switch self {
        case .integer(let num):
            id.num = num
        case .uuid(let uuid):
            id.uuid = uuid
        }
        return id
    }

    internal init?(grpc: Qdrant_PointId) {
        switch grpc.pointIDOptions {
        case .num(let num): self = .integer(num)
        case .uuid(let uuid): self = .uuid(uuid)
        case .none: return nil
        }
    }
}

extension VectorData {
    internal var grpc: Qdrant_Vectors {
        var vectors = Qdrant_Vectors()
        switch self {
        case .dense(let data):
            var denseVector = Qdrant_DenseVector()
            denseVector.data = data
            var vector = Qdrant_Vector()
            vector.dense = denseVector
            vectors.vector = vector
        case .named(let namedData):
            var namedVectors = Qdrant_NamedVectors()
            for (name, data) in namedData {
                var denseVector = Qdrant_DenseVector()
                denseVector.data = data
                var vector = Qdrant_Vector()
                vector.dense = denseVector
                namedVectors.vectors[name] = vector
            }
            vectors.vectors = namedVectors
        }
        return vectors
    }
}

extension Point {
    internal var grpc: Qdrant_PointStruct {
        var point = Qdrant_PointStruct()
        point.id = id.grpc
        point.vectors = vector.grpc

        if let payload = payload {
            for (key, value) in payload {
                point.payload[key] = value.grpc
            }
        }

        return point
    }
}

extension ScoredPoint {
    internal init?(grpc: Qdrant_ScoredPoint) {
        guard let id = PointID(grpc: grpc.id) else {
            return nil
        }

        var payload: [String: PayloadValue]? = nil
        if !grpc.payload.isEmpty {
            var payloadDict: [String: PayloadValue] = [:]
            for (key, value) in grpc.payload {
                payloadDict[key] = PayloadValue(grpc: value)
            }
            payload = payloadDict
        }

        var vector: VectorData? = nil
        if let vectorsOptions = grpc.vectors.vectorsOptions {
            switch vectorsOptions {
            case .vector(let output):
                if let vectorOption = output.vector {
                    switch vectorOption {
                    case .dense(let dense):
                        vector = .dense(dense.data)
                    default:
                        break
                    }
                }
            case .vectors(let named):
                var namedVectors: [String: [Float]] = [:]
                for (name, vectorOutput) in named.vectors {
                    if case .dense(let dense)? = vectorOutput.vector {
                        namedVectors[name] = dense.data
                    }
                }
                if !namedVectors.isEmpty {
                    vector = .named(namedVectors)
                }
            }
        }

        self.init(
            id: id,
            score: grpc.score,
            vector: vector,
            payload: payload,
            version: grpc.version
        )
    }
}

extension RetrievedPoint {
    internal init?(grpc: Qdrant_RetrievedPoint) {
        guard let id = PointID(grpc: grpc.id) else {
            return nil
        }

        var payload: [String: PayloadValue]? = nil
        if !grpc.payload.isEmpty {
            var payloadDict: [String: PayloadValue] = [:]
            for (key, value) in grpc.payload {
                payloadDict[key] = PayloadValue(grpc: value)
            }
            payload = payloadDict
        }

        var vector: VectorData? = nil
        if let vectorsOptions = grpc.vectors.vectorsOptions {
            switch vectorsOptions {
            case .vector(let output):
                if let vectorOption = output.vector {
                    switch vectorOption {
                    case .dense(let dense):
                        vector = .dense(dense.data)
                    default:
                        break
                    }
                }
            case .vectors(let named):
                var namedVectors: [String: [Float]] = [:]
                for (name, vectorOutput) in named.vectors {
                    if case .dense(let dense)? = vectorOutput.vector {
                        namedVectors[name] = dense.data
                    }
                }
                if !namedVectors.isEmpty {
                    vector = .named(namedVectors)
                }
            }
        }

        self.init(
            id: id,
            vector: vector,
            payload: payload
        )
    }
}
