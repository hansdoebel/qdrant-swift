import Foundation

/// Configuration for integration tests loaded from environment or .env file.
struct IntegrationTestConfig {
    let url: String
    let apiKey: String?
    let testCollection: String

    /// Whether this is a local Docker instance (no TLS, no API key required).
    var isLocal: Bool {
        url.contains("localhost") || url.contains("127.0.0.1")
    }

    /// Loads configuration from environment variables or .env file.
    ///
    /// For local Docker testing, only QDRANT_URL is required.
    /// QDRANT_API_KEY is optional for local instances.
    /// QDRANT_TEST_COLLECTION defaults to "test-collection" if not set.
    static func load() throws -> IntegrationTestConfig {
        // Try environment variables first
        if let url = ProcessInfo.processInfo.environment["QDRANT_URL"] {
            let apiKey = ProcessInfo.processInfo.environment["QDRANT_API_KEY"]
            let collection =
                ProcessInfo.processInfo.environment["QDRANT_TEST_COLLECTION"] ?? "test-collection"
            return IntegrationTestConfig(
                url: url,
                apiKey: apiKey?.isEmpty == true ? nil : apiKey,
                testCollection: collection
            )
        }

        // Fall back to .env file
        let envPath = findEnvFile()
        guard let envPath = envPath else {
            throw ConfigError.envFileNotFound
        }

        let envContent = try String(contentsOfFile: envPath, encoding: .utf8)
        var env: [String: String] = [:]

        for line in envContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(
                in: .whitespaces)
            env[key] = value
        }

        guard let url = env["QDRANT_URL"] else {
            throw ConfigError.missingRequiredKeys
        }

        let apiKey = env["QDRANT_API_KEY"]
        let collection = env["QDRANT_TEST_COLLECTION"] ?? "test-collection"

        return IntegrationTestConfig(
            url: url,
            apiKey: apiKey?.isEmpty == true ? nil : apiKey,
            testCollection: collection
        )
    }

    private static func findEnvFile() -> String? {
        // Look for .env file in common locations
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath

        // Try project root (relative to test bundle)
        let possiblePaths = [
            "\(currentDir)/.env",
            "\(currentDir)/../.env",
            "\(currentDir)/../../.env",
            "\(currentDir)/../../../.env",
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    enum ConfigError: Error, CustomStringConvertible {
        case envFileNotFound
        case missingRequiredKeys

        var description: String {
            switch self {
            case .envFileNotFound:
                return
                    "Could not find .env file. Set QDRANT_URL environment variable (QDRANT_API_KEY and QDRANT_TEST_COLLECTION are optional for local Docker)."
            case .missingRequiredKeys:
                return
                    "Missing required key in .env file: QDRANT_URL"
            }
        }
    }
}
