#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BRIDGE_DIR="$ROOT_DIR/anki-bridge-rs"
OUTPUT_DIR="$ROOT_DIR/AnkiRust.xcframework"
HEADER_DIR="$BRIDGE_DIR/include"

export PROTOC="${PROTOC:-$(which protoc 2>/dev/null || echo /opt/homebrew/bin/protoc)}"
export IPHONEOS_DEPLOYMENT_TARGET="17.0"
export WATCHOS_DEPLOYMENT_TARGET="11.0"

# watchOS is a tier-3 Rust target: std isn't distributed, so we build it from
# source with -Z build-std on nightly. Requires: rustup toolchain install nightly
# && rustup component add rust-src --toolchain nightly.
NIGHTLY="${NIGHTLY_TOOLCHAIN:-nightly}"

echo "==> Using protoc: $PROTOC"
echo "==> Deployment target: iOS $IPHONEOS_DEPLOYMENT_TARGET / watchOS $WATCHOS_DEPLOYMENT_TARGET"
echo "==> Building for iOS device (aarch64-apple-ios)..."
cargo build \
    --manifest-path "$BRIDGE_DIR/Cargo.toml" \
    --target aarch64-apple-ios \
    --release

echo "==> Building for iOS simulator (aarch64-apple-ios-sim)..."
cargo build \
    --manifest-path "$BRIDGE_DIR/Cargo.toml" \
    --target aarch64-apple-ios-sim \
    --release

echo "==> Building for watchOS simulator (aarch64-apple-watchos-sim, build-std)..."
# ponytail: sim slice only. The watchOS *device* target is arm64_32-apple-watchos
# (ILP32); add it here the same way once a physical-watch build is actually needed.
cargo "+$NIGHTLY" build \
    -Z build-std=std,panic_abort \
    --manifest-path "$BRIDGE_DIR/Cargo.toml" \
    --target aarch64-apple-watchos-sim \
    --release

DEVICE_LIB="$BRIDGE_DIR/target/aarch64-apple-ios/release/libanki_bridge_ios.a"
SIM_LIB="$BRIDGE_DIR/target/aarch64-apple-ios-sim/release/libanki_bridge_ios.a"
WATCH_SIM_LIB="$BRIDGE_DIR/target/aarch64-apple-watchos-sim/release/libanki_bridge_ios.a"

[ -f "$DEVICE_LIB" ] || { echo "ERROR: device lib not found at $DEVICE_LIB"; exit 1; }
[ -f "$SIM_LIB" ] || { echo "ERROR: simulator lib not found at $SIM_LIB"; exit 1; }
[ -f "$WATCH_SIM_LIB" ] || { echo "ERROR: watch simulator lib not found at $WATCH_SIM_LIB"; exit 1; }

echo "==> Device lib: $(du -h "$DEVICE_LIB" | cut -f1)"
echo "==> Simulator lib: $(du -h "$SIM_LIB" | cut -f1)"
echo "==> Watch simulator lib: $(du -h "$WATCH_SIM_LIB" | cut -f1)"

echo "==> Packaging XCFramework..."
rm -rf "$OUTPUT_DIR"

xcodebuild -create-xcframework \
    -library "$DEVICE_LIB" -headers "$HEADER_DIR" \
    -library "$SIM_LIB" -headers "$HEADER_DIR" \
    -library "$WATCH_SIM_LIB" -headers "$HEADER_DIR" \
    -output "$OUTPUT_DIR"

echo "==> Adding module maps..."
for HEADERS in "$OUTPUT_DIR"/*/Headers; do
    cat > "$HEADERS/module.modulemap" <<'MODULEMAP'
module AnkiRustLib {
    header "anki_bridge.h"
    export *
}
MODULEMAP
done

echo "==> Done! XCFramework at: $OUTPUT_DIR"
echo "==> Contents:"
find "$OUTPUT_DIR" -type f | head -15
