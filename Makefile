.PHONY: generate clean check-tools update-deps

PROTO_DIR = Sources/QdrantGRPC/Protos
OUTPUT_DIR = Sources/QdrantProto
# qdrant.proto is the public client surface. It intentionally omits imports of
# Qdrant's internal services (see the comment in that file).
PROTO_FILES = \
	$(PROTO_DIR)/collections.proto \
	$(PROTO_DIR)/collections_service.proto \
	$(PROTO_DIR)/health_check.proto \
	$(PROTO_DIR)/json_with_int.proto \
	$(PROTO_DIR)/points.proto \
	$(PROTO_DIR)/points_service.proto \
	$(PROTO_DIR)/qdrant.proto \
	$(PROTO_DIR)/qdrant_common.proto \
	$(PROTO_DIR)/snapshots_service.proto

# Well-known types such as google/protobuf/timestamp.proto.
PROTOC_INCLUDE ?= /usr/include

generate: check-tools
	@echo "Generating Swift code from proto files..."
	@mkdir -p $(OUTPUT_DIR)
	protoc \
		--proto_path=$(PROTO_DIR) \
		--proto_path=$(PROTOC_INCLUDE) \
		--swift_out=$(OUTPUT_DIR) \
		--swift_opt=Visibility=Public \
		--plugin=protoc-gen-grpc-swift=$$(command -v protoc-gen-grpc-swift-2) \
		--grpc-swift_out=$(OUTPUT_DIR) \
		--grpc-swift_opt=Visibility=Public \
		--grpc-swift_opt=Client=true \
		--grpc-swift_opt=Server=false \
		$(PROTO_FILES)
	@echo "Generated Swift files in $(OUTPUT_DIR)"

clean:
	@echo "Cleaning generated files..."
	rm -f $(OUTPUT_DIR)/*.pb.swift $(OUTPUT_DIR)/*.grpc.swift
	@echo "Done"

# Check for outdated dependencies
update-deps:
	swift package update --dry-run

# Check if protoc plugins are installed
check-tools:
	@command -v protoc >/dev/null || (echo "Error: protoc not found. Install with: brew install protobuf" && exit 1)
	@command -v protoc-gen-swift >/dev/null || (echo "Error: protoc-gen-swift not found. Install with: brew install swift-protobuf" && exit 1)
	@command -v protoc-gen-grpc-swift-2 >/dev/null || (echo "Error: protoc-gen-grpc-swift-2 not found. Build it from grpc-swift-protobuf 2.5.0." && exit 1)
	@echo "All required tools are installed"
