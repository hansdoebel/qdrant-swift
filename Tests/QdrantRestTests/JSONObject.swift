import Foundation

func roundTrip<T: Codable>(_ value: T) throws -> T {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(T.self, from: data)
}

func jsonObject(_ value: some Encodable, snakeCase: Bool = false) throws -> [String: Any] {
    let encoder = JSONEncoder()
    if snakeCase {
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    let data = try encoder.encode(value)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
}
