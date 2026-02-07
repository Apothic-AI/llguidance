#!/bin/sh

set -eu
set -x

cd "$(dirname "$0")/.."

rustup target add wasm32-unknown-unknown

cargo rustc \
    -p llguidance \
    --release \
    --target wasm32-unknown-unknown \
    --no-default-features \
    --features wasm,lark \
    -- \
    --crate-type cdylib

WASM_FILE=$(find target/wasm32-unknown-unknown/release -name 'llguidance*.wasm' | head -n1)

if [ -z "${WASM_FILE:-}" ] || [ ! -f "$WASM_FILE" ]; then
    echo "Missing expected wasm artifact under target/wasm32-unknown-unknown/release"
    exit 1
fi

# Validate that key C ABI exports are present in the wasm binary.
if command -v strings >/dev/null 2>&1; then
    strings "$WASM_FILE" | grep -q "llg_new_matcher"
    strings "$WASM_FILE" | grep -q "llg_matcher_compute_mask"
fi

echo "Built core wasm artifact: $WASM_FILE"
