# Qdrant v1.20.1 parity checklist

Source of truth: [Qdrant v1.20.1](https://github.com/qdrant/qdrant/releases/tag/v1.20.1) protos at `lib/api/src/grpc/proto`, plus the [1.20 blog](https://qdrant.tech/blog/qdrant-1.20.x/) and the REST documentation.

Public protos are vendored under `Sources/QdrantGRPC/Protos` and generated into `Sources/QdrantProto`. `qdrant.proto` keeps the upstream `HealthCheck` messages and omits imports of Qdrant's internal services (`collections_internal_service`, `points_internal_service`, `qdrant_internal_service`, `raft_service`, `shard_snapshots_service`, `storage_read_service`). Those RPCs are not part of the client API.

| Area | Proto (v1.20.1) | gRPC wrapper | REST wrapper |
| --- | --- | --- | --- |
| Toolchain: grpc-swift-2 2.4.4, nio-transport 2.x, grpc-protobuf 2.x, swift-protobuf 1.41.0, tools 6.4, macOS 27 / iOS 27 | n/a | done | done |
| `Package.resolved` committed, Makefile `generate` writes `Sources/QdrantProto` | done | n/a | n/a |
| CI unit tests on `xcode-27` / Xcode 27.2; integration tests on Linux against `qdrant/qdrant:v1.20.1` | n/a | done | done |
| MMR (`nearest_with_mmr`) | generated | done | done |
| Formula rescoring, including `acosh`, `max`, `min` | generated | done | done |
| Parameterized RRF (`k`, `weights`) and DBSF fusion | generated | done | done |
| `VectorInput`: sparse, multi-dense, `Document`, `Image`, `InferenceObject` | generated | done | done |
| `TextQuery` + `Bm25Params`, `IdfParams`, `RelevanceFeedbackInput`, prefetch nesting | generated | done | done |
| `query` / `queryBatch` / `queryGroups` on `PointsServiceProtocol` (mocks) | generated | done | done |
| Filter: `minShould`, nested, `hasVector`, phrase, `textAny`, `valuesCount`, datetime range, geo polygon | generated | pending | pending |
| Match: `prefix`, `substring` | generated | pending | pending |
| `SliceCondition` | generated | pending | pending |
| `FieldType` uuid | generated | pending | pending |
| Text index: BM25 `TextScoringParams`, `code` tokenizer, `DisabledStemmer`, per-element `nested` | generated | pending | pending |
| TurboQuant datatypes (`turbo8` / `turbo16`) and `TurboQuantization` | generated | pending | pending |
| Memory placement; `on_disk` / `always_ram` / `on_disk_payload` deprecated, not removed | generated | pending | pending |
| `IdTrackerParams`, `PayloadStorageParams` | generated | pending | pending |
| Collection info `created_at`, `update_queue` | generated | pending | pending |
| Strict mode `require_tenant_filter`, `search_max_batchsize`; `max_resident_memory_percent` deprecated | generated | pending | pending |
| Upsert `UpdateMode` (`insert_only` / `update_only`) | generated | pending | pending |
| `CreateVectorName` / `DeleteVectorName` | generated | pending | pending |

Internal-only protos are intentionally not vendored. Snapshot storage backends (GCS, Azure), audit-log sinks, and `cluster.p2p.host` are server configuration, not client RPCs.
