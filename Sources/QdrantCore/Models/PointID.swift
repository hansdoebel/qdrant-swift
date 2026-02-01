import Foundation

public enum PointID: Sendable, Hashable {
    case integer(UInt64)

    case uuid(String)

    public static func uuid(_ uuid: UUID) -> PointID {
        .uuid(uuid.uuidString.lowercased())
    }
}

extension PointID: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self = .integer(value)
    }
}

extension PointID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .uuid(value)
    }
}

extension PointID: CustomStringConvertible {
    public var description: String {
        switch self {
        case .integer(let num): String(num)
        case .uuid(let uuid): uuid
        }
    }
}

extension PointID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(UInt64.self) {
            self = .integer(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .uuid(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                PointID.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Expected UInt64 or String")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let num): try container.encode(num)
        case .uuid(let uuid): try container.encode(uuid)
        }
    }
}
