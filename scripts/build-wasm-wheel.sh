#!/bin/sh

set -eu
set -x

cd "$(dirname "$0")/.."

if ! command -v python >/dev/null 2>&1; then
    echo "python is required"
    exit 1
fi

TARGET=${LLG_WASM_PY_TARGET:-wasm32-wasip1}

# Use python -m for reproducibility with the active interpreter environment.
python -m pip install --upgrade maturin
rustup target add "$TARGET"

python -m maturin build \
    --release \
    --target "$TARGET" \
    --compatibility off \
    --out target/wasm-wheels

echo "Built wasm wheel(s) in target/wasm-wheels"
