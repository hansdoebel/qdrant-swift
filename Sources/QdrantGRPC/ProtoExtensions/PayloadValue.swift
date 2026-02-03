import Foundation
import QdrantCore
import QdrantProto

public typealias PayloadValue = QdrantCore.PayloadValue

extension PayloadValue {
    /// Converts to the gRPC Value representation.
    internal var grpc: Qdrant_Value {
        var value = Qdrant_Value()
        switch self {
        case .null:
            value.nullValue = .nullValue
        case .bool(let b):
            value.boolValue = b
        case .integer(let i):
            value.integerValue = i
        case .double(let d):
            value.doubleValue = d
        case .string(let s):
            value.stringValue = s
        case .array(let arr):
            var list = Qdrant_ListValue()
            list.values = arr.map { $0.grpc }
            value.listValue = list
        case .object(let dict):
            var structValue = Qdrant_Struct()
            for (k, v) in dict {
                structValue.fields[k] = v.grpc
            }
            value.structValue = structValue
        }
        return value
    }

    /// Creates from the gRPC Value representation.
    internal init(grpc: Qdrant_Value) {
        self =
            switch grpc.kind {
            case .nullValue: .null
            case .boolValue(let b): .bool(b)
            case .integerValue(let i): .integer(i)
            case .doubleValue(let d): .double(d)
            case .stringValue(let s): .string(s)
            case .listValue(let list): .array(list.values.map { PayloadValue(grpc: $0) })
            case .structValue(let structValue):
                .object(structValue.fields.mapValues { PayloadValue(grpc: $0) })
            case .none: .null
            }
    }
}
