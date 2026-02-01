import Foundation

public enum Distance: Sendable, Hashable {
    case cosine

    case euclid

    case dot

    case manhattan
}

extension Distance: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        self =
            switch rawValue.lowercased() {
            case "cosine": .cosine
            case "euclid", "euclidean": .euclid
            case "dot": .dot
            case "manhattan": .manhattan
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown distance metric: \(rawValue)"
                )
            }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let value =
            switch self {
            case .cosine: "Cosine"
            case .euclid: "Euclid"
            case .dot: "Dot"
            case .manhattan: "Manhattan"
            }
        try container.encode(value)
    }
}
