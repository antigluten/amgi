#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PROTO_DIR="$ROOT_DIR/anki-upstream/proto"
OUTPUT_DIR="$ROOT_DIR/Sources/AnkiProto"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.pb.swift

echo "==> Generating Swift protobuf types..."
protoc \
    --proto_path="$PROTO_DIR" \
    --swift_out="$OUTPUT_DIR" \
    --swift_opt=Visibility=Public \
    "$PROTO_DIR"/anki/*.proto

# Flatten: protoc creates an anki/ subdirectory matching the proto package path
if [ -d "$OUTPUT_DIR/anki" ]; then
    mv "$OUTPUT_DIR"/anki/*.pb.swift "$OUTPUT_DIR/"
    rmdir "$OUTPUT_DIR/anki"
fi

# Fix imports for InternalImportsByDefault (Swift 6.2)
# protoc-gen-swift generates `import SwiftProtobuf` which is internal by default.
# Public types need `public import`.
echo "==> Fixing imports for InternalImportsByDefault..."
for f in "$OUTPUT_DIR"/*.pb.swift; do
    sed -i '' 's/^import SwiftProtobuf/public import SwiftProtobuf/' "$f"
    sed -i '' 's/^import Foundation/public import Foundation/' "$f"
done

COUNT=$(ls "$OUTPUT_DIR"/*.pb.swift 2>/dev/null | wc -l | tr -d ' ')
echo "==> Generated $COUNT files in $OUTPUT_DIR"
