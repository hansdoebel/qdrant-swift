import Foundation

public enum PayloadValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case integer(Int64)
    case double(Double)
    case string(String)
    case array([PayloadValue])
    case object([String: PayloadValue])
}

extension PayloadValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension PayloadValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension PayloadValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = .integer(value)
    }
}

extension PayloadValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension PayloadValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension PayloadValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: PayloadValue...) {
        self = .array(elements)
    }
}

extension PayloadValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, PayloadValue)...) {
        var dict: [String: PayloadValue] = [:]
        for (k, v) in elements {
            dict[k] = v
        }
        self = .object(dict)
    }
}

extension PayloadValue {
    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var integerValue: Int64? {
        if case .integer(let i) = self { return i }
        return nil
    }

    public var doubleValue: Double? {
        if case .double(let d) = self { return d }
        return nil
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var arrayValue: [PayloadValue]? {
        if case .array(let arr) = self { return arr }
        return nil
    }

    public var objectValue: [String: PayloadValue]? {
        if case .object(let dict) = self { return dict }
        return nil
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public subscript(index: Int) -> PayloadValue? {
        if case .array(let arr) = self, index >= 0 && index < arr.count {
            return arr[index]
        }
        return nil
    }

    public subscript(key: String) -> PayloadValue? {
        if case .object(let dict) = self {
            return dict[key]
        }
        return nil
    }
}

extension PayloadValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .null: "null"
        case .bool(let b): String(b)
        case .integer(let i): String(i)
        case .double(let d): String(d)
        case .string(let s): "\"\(s)\""
        case .array(let arr): "[\(arr.map { $0.description }.joined(separator: ", "))]"
        case .object(let dict):
            "{\(dict.map { "\"\($0.key)\": \($0.value.description)" }.joined(separator: ", "))}"
        }
    }
}

extension PayloadValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int64.self) {
            self = .integer(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([PayloadValue].self) {
            self = .array(arrayValue)
        } else if let objectValue = try? container.decode([String: PayloadValue].self) {
            self = .object(objectValue)
        } else {
            throw DecodingError.typeMismatch(
                PayloadValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode payload value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let b): try container.encode(b)
        case .integer(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .string(let s): try container.encode(s)
        case .array(let arr): try container.encode(arr)
        case .object(let dict): try container.encode(dict)
        }
    }
}
