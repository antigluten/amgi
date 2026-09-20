#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BRIDGE_DIR="$ROOT_DIR/anki-bridge-rs"
OUTPUT_DIR="$ROOT_DIR/AnkiRustLib.xcframework"
STAGE_DIR="$BRIDGE_DIR/target/xcframework-stage"
HEADER="$BRIDGE_DIR/include/anki_bridge.h"

export PROTOC="${PROTOC:-$(which protoc 2>/dev/null || echo /opt/homebrew/bin/protoc)}"

# anki_proto's build script writes the protobuf descriptor pool and anki's build
# script reads it back. With no DESCRIPTORS_BIN set they agree only by way of
# `OUT_DIR/../../anki_descriptors.bin`, which assumes cargo's old
# `build/<crate>-<hash>/` layout. Cargo's newer `build/<crate>/<hash>/` layout
# gives each crate its own parent, so the reader looks in build/anki/ for a file
# the writer put in build/anki_proto/ and the build dies with a bare
# "Error: No such file or directory (os error 2)". Pinning one absolute path
# sidesteps the layout entirely.
mkdir -p "$BRIDGE_DIR/target"
export DESCRIPTORS_BIN="$BRIDGE_DIR/target/anki_descriptors.bin"

export IPHONEOS_DEPLOYMENT_TARGET="17.0"
export WATCHOS_DEPLOYMENT_TARGET="11.0"

# The crate is a cdylib, not a staticlib, and it ships as a *dynamic* framework.
# That is load-bearing for SwiftUI previews: XCPreviewAgent JIT-links a package
# target against the dylibs in the products dir, so a static archive's symbols
# (anki_open_backend & friends) are simply absent and every preview that
# transitively reaches AnkiBackend dies with
#   JITError: Symbols not found: [_anki_open_backend, ...]
# Do not switch this back to `staticlib` without re-breaking that.
export RUSTFLAGS="${RUSTFLAGS:-} -C link-arg=-Wl,-install_name,@rpath/AnkiRustLib.framework/AnkiRustLib"

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

# Wrap one cdylib into AnkiRustLib.framework. $1 = rust triple, $2 = slice name,
# $3 = CFBundleSupportedPlatforms entry, $4 = MinimumOSVersion.
make_framework() {
    local triple="$1" slice="$2" platform="$3" minos="$4"
    local dylib="$BRIDGE_DIR/target/$triple/release/libanki_bridge_ios.dylib"
    [ -f "$dylib" ] || { echo "ERROR: dylib not found at $dylib"; exit 1; }

    local fw="$STAGE_DIR/$slice/AnkiRustLib.framework"
    rm -rf "$fw"

    local root="$fw" plist_dir="$fw"
    mkdir -p "$root/Headers" "$root/Modules"
    cp "$dylib" "$root/AnkiRustLib"
    cp "$HEADER" "$root/Headers/"

    cat > "$root/Modules/module.modulemap" <<'MODULEMAP'
framework module AnkiRustLib {
    header "anki_bridge.h"
    export *
}
MODULEMAP

    cat > "$plist_dir/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>AnkiRustLib</string>
    <key>CFBundleIdentifier</key><string>com.amgi.AnkiRustLib</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>AnkiRustLib</string>
    <key>CFBundlePackageType</key><string>FMWK</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
    <key>MinimumOSVersion</key><string>$minos</string>
</dict>
</plist>
PLIST

    echo "==> $slice: $(du -h "$root/AnkiRustLib" | cut -f1)"
}

echo "==> Staging frameworks..."
rm -rf "$STAGE_DIR"
make_framework aarch64-apple-ios            ios-device  iPhoneOS        "$IPHONEOS_DEPLOYMENT_TARGET"
make_framework aarch64-apple-ios-sim        ios-sim     iPhoneSimulator "$IPHONEOS_DEPLOYMENT_TARGET"
make_framework aarch64-apple-watchos-sim    watchos-sim WatchSimulator  "$WATCHOS_DEPLOYMENT_TARGET"

echo "==> Packaging XCFramework..."
rm -rf "$OUTPUT_DIR"
xcodebuild -create-xcframework \
    -framework "$STAGE_DIR/ios-device/AnkiRustLib.framework" \
    -framework "$STAGE_DIR/ios-sim/AnkiRustLib.framework" \
    -framework "$STAGE_DIR/watchos-sim/AnkiRustLib.framework" \
    -output "$OUTPUT_DIR"

echo "==> Restoring cargo binaries over the packaged ones (LINKEDIT alignment)..."
restore_binary() {
    local triple="$1" slice="$2"
    local dylib="$BRIDGE_DIR/target/$triple/release/libanki_bridge_ios.dylib"
    local packaged="$OUTPUT_DIR/$slice/AnkiRustLib.framework/AnkiRustLib"
    cp "$dylib" "$packaged"

    # Fail loudly rather than hand a broken xcframework to every consumer.
    local stroff
    stroff=$(otool -l "$packaged" | awk '/LC_SYMTAB/{f=1} f&&/stroff/{print $2; exit}')
    # An empty stroff would make the arithmetic below read 0 and pass.
    [ -n "$stroff" ] || { echo "ERROR: $slice: could not parse LC_SYMTAB stroff from otool"; exit 1; }
    if [ $((stroff % 8)) -ne 0 ]; then
        echo "ERROR: $slice LC_SYMTAB string pool is mis-aligned (stroff=$stroff)."
        echo "       ld will reject this framework. See the comment above this check."
        exit 1
    fi
    echo "==> $slice: stroff=$stroff (8-byte aligned)"
}

restore_binary aarch64-apple-ios         ios-arm64
restore_binary aarch64-apple-ios-sim     ios-arm64-simulator
restore_binary aarch64-apple-watchos-sim watchos-arm64-simulator

echo "==> Done! XCFramework at: $OUTPUT_DIR"
echo "==> Contents:"
find "$OUTPUT_DIR" -maxdepth 3 | head -20
