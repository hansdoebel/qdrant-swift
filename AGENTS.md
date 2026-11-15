# AGENTS.md

## Overview

`qdrant-swift` is the Swift client for Qdrant 1.20.1. It ships three libraries:

- `QdrantCore` holds the shared models and service protocols.
- `QdrantGRPC` is the gRPC client.
- `QdrantREST` is the REST client and has no third-party dependencies.

The package requires Swift 6.4, macOS 27, and iOS 27. The suggested package version is 2.0.0. Do not create or push a git tag or GitHub release. Hans decides that.

## Layout

```
Sources/QdrantCore/          models and protocols
Sources/QdrantGRPC/Protos/   vendored public .proto files
Sources/QdrantGRPC/          client, services, and proto mappings
Sources/QdrantProto/         generated Swift
Sources/QdrantRest/          REST client
Tests/QdrantCoreTests/       model tests
Tests/QdrantGRPCTests/       gRPC mapping tests
Tests/QdrantRestTests/       REST encoding tests
Tests/IntegrationTests/      live server tests
Tests/Mocks/                 protocol mocks
Docs/                        usage, API, testing, and the parity checklist
```

## Generated protos and handwritten code

`Sources/QdrantGRPC/Protos` is the public subset of Qdrant v1.20.1 `lib/api/src/grpc/proto`. `qdrant.proto` keeps the upstream `HealthCheck` messages and omits the internal service imports.

`make generate` writes `Sources/QdrantProto`. Do not edit those files by hand. Handwritten mapping lives in `Sources/QdrantGRPC/ProtoExtensions` and the service types. REST JSON lives in `Sources/QdrantRest`.

Field names come from the protos and the Qdrant REST schema. Do not invent fields. `Docs/PARITY.md` is the checklist for that surface.

## Build and test

Toolchain: Swift 6.4. Apple platforms: macOS 27 and iOS 27. The macOS CI job uses the `xcode-27` runner and `/Applications/Xcode_27.2.app`.

```bash
swift test --skip IntegrationTests
swift test --filter IntegrationTests
```

Integration tests need `QDRANT_URL` (for local Docker, `http://localhost:6333`) and `qdrant/qdrant:v1.20.1` from `docker-compose.test.yml`. GitHub Actions service containers are not supported on macOS runners, so the live Qdrant job runs on Linux.

Regenerate protos with `make generate` after `protoc`, `protoc-gen-swift`, and `protoc-gen-grpc-swift-2` are on `PATH`. `make update-deps` reports available package updates. `Package.resolved` is committed.

## Conventions

Do not add code comments. Names should match the proto or REST field they wrap.

`onDisk`, `alwaysRam`, and `onDiskPayload` stay in the API and are marked `@available(*, deprecated)`. Callers should use `MemoryTier` and `payload.memory` instead.

A public behavior change needs a unit test that checks the gRPC message or the REST JSON. Do not change that behavior while cleaning up.

## Pull requests

Open each pull request against `main`. Keep it focused. The body lists the unit test command and counts, plus anything that still needs a live Qdrant or a manual check.

Squash-merge only after the unit tests and both CI jobs are green: Xcode 27.2 unit tests, and the Linux job against `qdrant/qdrant:v1.20.1`.

Do not create or push a git tag or GitHub release.
