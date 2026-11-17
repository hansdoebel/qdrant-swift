# Qdrant v1.20.2 parity checklist

Source of truth: [Qdrant v1.20.2](https://github.com/qdrant/qdrant/releases/tag/v1.20.2) protos at `lib/api/src/grpc/proto`, plus the [1.20 blog](https://qdrant.tech/blog/qdrant-1.20.x/) and the REST documentation.

Public protos are vendored under `Sources/QdrantGRPC/Protos` and generated into `Sources/QdrantProto`. `qdrant.proto` keeps the upstream `HealthCheck` messages and omits imports of Qdrant's internal services (`collections_internal_service`, `points_internal_service`, `qdrant_internal_service`, `raft_service`, `shard_snapshots_service`, `storage_read_service`). Those RPCs are not part of the client API.

| Area | Proto (v1.20.2) | gRPC wrapper | REST wrapper |
| --- | --- | --- | --- |
| Toolchain: grpc-swift-2 2.4.4, nio-transport 2.x, grpc-protobuf 2.x, swift-protobuf 1.41.0, tools 6.4, macOS 27 / iOS 27 | n/a | done | done |
| `Package.resolved` committed, Makefile `generate` writes `Sources/QdrantProto` | done | n/a | n/a |
| CI unit tests on `xcode-27` / Xcode 27.2; integration tests on Linux against `qdrant/qdrant:v1.20.2` | n/a | done | done |
| MMR (`nearest_with_mmr`) | generated | done | done |
| Formula rescoring, including `acosh`, `max`, `min` | generated | done | done |
| Parameterized RRF (`k`, `weights`) and DBSF fusion | generated | done | done |
| `VectorInput`: sparse, multi-dense, `Document`, `Image`, `InferenceObject` | generated | done | done |
| `TextQuery` + `Bm25Params`, `IdfParams`, `RelevanceFeedbackInput`, prefetch nesting | generated | done | done |
| `query` / `queryBatch` / `queryGroups` on `PointsServiceProtocol` (mocks) | generated | done | done |
| Filter: `minShould`, nested, `hasVector`, phrase, `textAny`, `valuesCount`, datetime range, geo polygon | generated | done | done |
| Match: `prefix`, `substring` | generated | done | done |
| `SliceCondition` | generated | done | done |
| `FieldType` uuid | generated | done | done |
| Text index: BM25 `TextScoringParams`, `code` tokenizer, `DisabledStemmer`, per-element `nested` | generated | done | done |
| TurboQuant datatypes (`turbo8` / `turbo16`) and `TurboQuantization` | generated | done | done |
| Memory placement; `on_disk` / `always_ram` / `on_disk_payload` deprecated, not removed | generated | done | done |
| `IdTrackerParams`, `PayloadStorageParams` | generated | done | done |
| Collection info `created_at`, `update_queue` | generated | done | done |
| Strict mode `enabled`, `require_tenant_filter`, `search_max_batchsize`; `max_resident_memory_percent` deprecated | generated | done | done |
| Upsert `UpdateMode` (`insert_only` / `update_only`) | generated | done | done |
| `CreateVectorName` / `DeleteVectorName` | generated | done | done |

Internal-only protos are intentionally not vendored. Snapshot storage backends (GCS, Azure), audit-log sinks, and `cluster.p2p.host` are server configuration, not client RPCs.

## 1.20.2 compatibility

The public protobuf usage counters include `updated_bytes` and `updated_indexed_bytes`, preserving optional-field presence. REST response envelopes intentionally expose result data rather than usage metrics; absent, null, partial and extended usage objects are accepted. The server now defaults PiPNN graph building off; this client does not override that default or change existing collection settings.
