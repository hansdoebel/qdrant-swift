import GRPCCore
import Testing
@testable import QdrantGRPC

struct DeadlineTests {
    @Test(arguments: [Duration.seconds(30), .seconds(73), .milliseconds(125)])
    func configuredDeadlineAppliesToEveryService(timeout: Duration) throws {
        let configuration = try QdrantConfiguration(timeout: timeout)
        let transport = try QdrantGRPCClient.makeTransport(configuration: configuration)
        for (service, method) in [
            ("qdrant.Qdrant", "HealthCheck"),
            ("qdrant.Collections", "List"),
            ("qdrant.Collections", "Create"),
            ("qdrant.Points", "Query"),
            ("qdrant.Points", "Upsert"),
            ("qdrant.Snapshots", "Create"),
            ("future.Service", "FutureMethod")
        ] {
            let descriptor = MethodDescriptor(fullyQualifiedService: service, method: method)
            let options = try #require(transport.config(forMethod: descriptor))
            #expect(options.timeout == timeout)
            #expect(options.executionPolicy == nil)
            #expect(options.waitForReady == nil)
            #expect(options.maxRequestMessageBytes == nil)
            #expect(options.maxResponseMessageBytes == nil)
        }
    }

    @Test func defaultConfigurationHasThirtySecondDeadline() throws {
        let transport = try QdrantGRPCClient.makeTransport(configuration: QdrantConfiguration())
        let options = try #require(transport.config(forMethod:
            MethodDescriptor(fullyQualifiedService: "qdrant.Qdrant", method: "HealthCheck")))
        #expect(options.timeout == .seconds(30))
    }
}
