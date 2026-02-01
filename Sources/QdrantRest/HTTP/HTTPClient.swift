import Foundation

// MARK: - CharacterSet Extension for URL Path Components

extension CharacterSet {
    /// Characters allowed in a single URL path component (segment).
    /// This is more restrictive than `.urlPathAllowed` as it excludes `/`.
    static let urlPathComponentAllowed: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")  // Don't allow path separators in segments
        return allowed
    }()
}

/// HTTP client wrapper for Qdrant REST API using URLSession.
public actor HTTPClient {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a new HTTP client.
    /// - Parameters:
    ///   - host: The hostname of the Qdrant server.
    ///   - port: The REST API port (default 6333).
    ///   - useTLS: Whether to use HTTPS.
    ///   - apiKey: Optional API key for authentication.
    ///   - session: URLSession to use (default shared session).
    public init(
        host: String,
        port: Int = 6333,
        useTLS: Bool = false,
        apiKey: String? = nil,
        session: URLSession = .shared
    ) throws {
        let scheme = useTLS ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(host):\(port)") else {
            throw HTTPError.invalidURL("\(scheme)://\(host):\(port)")
        }

        self.baseURL = url
        self.apiKey = apiKey
        self.session = session

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Request Methods

    /// Performs a GET request.
    /// - Parameters:
    ///   - path: The API path.
    ///   - queryItems: Optional query parameters.
    /// - Returns: The decoded response.
    public func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let request = try buildRequest(method: "GET", path: path, queryItems: queryItems)
        return try await execute(request)
    }

    /// Performs a GET request and returns raw text.
    /// - Parameters:
    ///   - path: The API path.
    ///   - queryItems: Optional query parameters.
    /// - Returns: The response body as a string.
    public func getText(
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> String {
        let request = try buildRequest(method: "GET", path: path, queryItems: queryItems)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        guard let text = String(data: data, encoding: .utf8) else {
            throw HTTPError.decodingFailed(
                NSError(
                    domain: "HTTPClient", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not decode response as UTF-8 text"]
                ))
        }
        return text
    }

    /// Performs a POST request.
    /// - Parameters:
    ///   - path: The API path.
    ///   - body: The request body.
    ///   - queryItems: Optional query parameters.
    /// - Returns: The decoded response.
    public func post<T: Decodable, B: Encodable>(
        path: String,
        body: B,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        var request = try buildRequest(method: "POST", path: path, queryItems: queryItems)
        request.httpBody = try encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    /// Performs a POST request without a response body.
    /// - Parameters:
    ///   - path: The API path.
    ///   - body: The request body.
    ///   - queryItems: Optional query parameters.
    public func post<B: Encodable>(
        path: String,
        body: B,
        queryItems: [URLQueryItem]? = nil
    ) async throws {
        var request = try buildRequest(method: "POST", path: path, queryItems: queryItems)
        request.httpBody = try encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await executeVoid(request)
    }

    /// Performs a PUT request.
    /// - Parameters:
    ///   - path: The API path.
    ///   - body: The request body.
    ///   - queryItems: Optional query parameters.
    /// - Returns: The decoded response.
    public func put<T: Decodable, B: Encodable>(
        path: String,
        body: B,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        var request = try buildRequest(method: "PUT", path: path, queryItems: queryItems)
        request.httpBody = try encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    /// Performs a PUT request without a response body.
    /// - Parameters:
    ///   - path: The API path.
    ///   - body: The request body.
    ///   - queryItems: Optional query parameters.
    public func put<B: Encodable>(
        path: String,
        body: B,
        queryItems: [URLQueryItem]? = nil
    ) async throws {
        var request = try buildRequest(method: "PUT", path: path, queryItems: queryItems)
        request.httpBody = try encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await executeVoid(request)
    }

    /// Performs a PATCH request.
    /// - Parameters:
    ///   - path: The API path.
    ///   - body: The request body.
    ///   - queryItems: Optional query parameters.
    /// - Returns: The decoded response.
    public func patch<T: Decodable, B: Encodable>(
        path: String,
        body: B,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        var request = try buildRequest(method: "PATCH", path: path, queryItems: queryItems)
        request.httpBody = try encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    /// Performs a DELETE request.
    /// - Parameters:
    ///   - path: The API path.
    ///   - queryItems: Optional query parameters.
    /// - Returns: The decoded response.
    public func delete<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let request = try buildRequest(method: "DELETE", path: path, queryItems: queryItems)
        return try await execute(request)
    }

    /// Performs a DELETE request without a response body.
    /// - Parameters:
    ///   - path: The API path.
    ///   - queryItems: Optional query parameters.
    public func delete(
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws {
        let request = try buildRequest(method: "DELETE", path: path, queryItems: queryItems)
        try await executeVoid(request)
    }

    /// Performs a DELETE request with a body.
    /// - Parameters:
    ///   - path: The API path.
    ///   - body: The request body.
    ///   - queryItems: Optional query parameters.
    /// - Returns: The decoded response.
    public func delete<T: Decodable, B: Encodable>(
        path: String,
        body: B,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        var request = try buildRequest(method: "DELETE", path: path, queryItems: queryItems)
        request.httpBody = try encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    /// Downloads a file to a local path.
    /// - Parameters:
    ///   - path: The API path to download from.
    ///   - destination: The local file URL to save to.
    public func download(
        path: String,
        to destination: URL
    ) async throws {
        let request = try buildRequest(method: "GET", path: path, queryItems: nil)
        let (tempURL, response) = try await session.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.unexpectedResponse("Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HTTPError.statusCode(httpResponse.statusCode, message: "Download failed")
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempURL, to: destination)
    }

    // MARK: - Private Helpers

    private func buildRequest(
        method: String,
        path: String,
        queryItems: [URLQueryItem]?
    ) throws -> URLRequest {
        // Encode each path segment to prevent URL injection attacks
        let encodedPath = encodePathSegments(path)

        var components = URLComponents(
            url: baseURL.appendingPathComponent(encodedPath), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw HTTPError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "api-key")
        }

        return request
    }

    /// Encodes each segment of a URL path to prevent injection attacks.
    /// This ensures characters like `/`, `?`, `#`, `%` in user input are properly escaped.
    private func encodePathSegments(_ path: String) -> String {
        // Split by `/`, encode each segment, rejoin
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        let encodedSegments = segments.map { segment -> String in
            // Use percent encoding for path components
            // This encodes special characters but preserves alphanumerics and some safe chars
            let segmentString = String(segment)
            return segmentString.addingPercentEncoding(
                withAllowedCharacters: .urlPathComponentAllowed) ?? segmentString
        }
        return encodedSegments.joined(separator: "/")
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw HTTPError.encodingFailed(error)
        }
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPError.decodingFailed(error)
        }
    }

    private func executeVoid(_ request: URLRequest) async throws {
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw HTTPError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.unexpectedResponse("Not an HTTP response")
        }

        let statusCode = httpResponse.statusCode

        guard (200...299).contains(statusCode) else {
            let message = extractErrorMessage(from: data)

            switch statusCode {
            case 400:
                throw HTTPError.badRequest(message ?? "Bad request")
            case 401:
                throw HTTPError.unauthenticated
            case 403:
                throw HTTPError.permissionDenied
            case 404:
                if let message = message, message.lowercased().contains("collection") {
                    throw HTTPError.collectionNotFound(message)
                } else if let message = message, message.lowercased().contains("point") {
                    throw HTTPError.pointNotFound(message)
                }
                throw HTTPError.statusCode(statusCode, message: message)
            case 500...599:
                throw HTTPError.serverError(message ?? "Internal server error")
            default:
                throw HTTPError.statusCode(statusCode, message: message)
            }
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let status: ErrorStatus?
            let message: String?

            struct ErrorStatus: Decodable {
                let error: String?
            }
        }

        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
            return errorResponse.status?.error ?? errorResponse.message
        }

        return String(data: data, encoding: .utf8)
    }
}
