public struct HealthCheckResult: Sendable {
    public let title: String

    public let version: String

    public let commit: String?

    public init(title: String, version: String, commit: String? = nil) {
        self.title = title
        self.version = version
        self.commit = commit
    }
}
