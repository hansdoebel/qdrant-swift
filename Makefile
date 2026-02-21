.PHONY: generate clean check-tools update-deps

PROTO_DIR = protos
OUTPUT_DIR = Sources/QdrantGRPC
PROTO_FILES = $(wildcard $(PROTO_DIR)/*.proto)

generate:
	@echo "Generating Swift code from proto files..."
	@mkdir -p $(OUTPUT_DIR)
	protoc \
		--proto_path=$(PROTO_DIR) \
		--swift_out=$(OUTPUT_DIR) \
		--swift_opt=Visibility=Public \
		--plugin=protoc-gen-grpc-swift=/opt/homebrew/bin/protoc-gen-grpc-swift-2 \
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
	@which protoc > /dev/null || (echo "Error: protoc not found. Install with: brew install protobuf" && exit 1)
	@which protoc-gen-swift > /dev/null || (echo "Error: protoc-gen-swift not found. Install with: brew install swift-protobuf" && exit 1)
	@which protoc-gen-grpc-swift-2 > /dev/null || (echo "Error: protoc-gen-grpc-swift-2 not found. Install with: brew install grpc-swift" && exit 1)
	@echo "All required tools are installed"
