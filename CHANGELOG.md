# Changelog

## 2.0.0

Suggested release. This tag has not been created.

This release targets Qdrant 1.20.1 and drops the previous toolchain. Swift 6.4, macOS 27, and iOS 27 are required. The gRPC stack is `grpc-swift-2` 2.4.4, `grpc-swift-nio-transport` 2.12.0, `grpc-swift-protobuf` 2.5.0, and `swift-protobuf` 1.41.0.

### Query API

- MMR (`nearest_with_mmr`), formula rescoring (`acosh`, `max`, `min`), weighted RRF, and DBSF.
- Sparse, multi-dense, document, image, and inference-object vector inputs.
- Text queries with BM25 parameters, IDF corpus selection, relevance feedback, and nested prefetch.
- `query`, `queryBatch`, and `queryGroups` are on `PointsServiceProtocol`.

### Filters and indexes

- `min_should`, nested filters, `has_vector`, phrase, `text_any`, value counts, datetime ranges, geo polygons, prefix, substring, and slice conditions.
- `uuid` payload fields.
- Text indexes with BM25 scoring, the `code` tokenizer, a disabled stemmer, and per-element nested indexes.

### Collections and points

- `turbo8` and `turbo16` datatypes, and TurboQuant quantization.
- Memory tiers (`cold`, `cached`, `pinned`). `onDisk`, `alwaysRam`, and `onDiskPayload` remain and are deprecated.
- Payload storage and ID tracker placement.
- Collection info `createdAt` and `updateQueue`.
- Strict mode `requireTenantFilter` and `searchMaxBatchsize`. `maxResidentMemoryPercent` is deprecated.
- Upsert `UpdateMode` (`insert_only`, `update_only`).
- Create and delete named vectors.

### Tooling

- `Package.resolved` is committed.
- `make generate` reads `Sources/QdrantGRPC/Protos` and writes `Sources/QdrantProto`.
- GitHub Actions runs unit tests on the `xcode-27` runner with Xcode 27.2, and integration tests on Linux against `qdrant/qdrant:v1.20.1`. Service containers are not available on macOS runners.
