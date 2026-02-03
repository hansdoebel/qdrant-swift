import Foundation
import QdrantCore
import QdrantProto

public typealias CollectionStatus = QdrantCore.CollectionStatus
public typealias CollectionInfo = QdrantCore.CollectionInfo
public typealias CollectionDescription = QdrantCore.CollectionDescription
public typealias AliasDescription = QdrantCore.AliasDescription

extension CollectionStatus {
    internal init(grpc: Qdrant_CollectionStatus) {
        self =
            switch grpc {
            case .green: .green
            case .yellow: .yellow
            case .red: .red
            case .grey: .grey
            default: .unknown
            }
    }
}

extension CollectionInfo {
    internal init(name: String, grpc: Qdrant_CollectionInfo) {
        self.init(
            name: name,
            status: CollectionStatus(grpc: grpc.status),
            indexedVectorsCount: grpc.hasIndexedVectorsCount ? grpc.indexedVectorsCount : nil,
            pointsCount: grpc.hasPointsCount ? grpc.pointsCount : nil,
            segmentsCount: grpc.segmentsCount
        )
    }
}

extension CollectionDescription {
    internal init(grpc: Qdrant_CollectionDescription) {
        self.init(name: grpc.name)
    }
}

extension AliasDescription {
    internal init(grpc: Qdrant_AliasDescription) {
        self.init(aliasName: grpc.aliasName, collectionName: grpc.collectionName)
    }
}
