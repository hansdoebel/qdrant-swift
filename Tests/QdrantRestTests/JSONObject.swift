import Foundation

func jsonObject(_ value: some Encodable, snakeCase: Bool = false) throws -> [String: Any] {
    let encoder = JSONEncoder()
    if snakeCase {
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    let data = try encoder.encode(value)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
}
