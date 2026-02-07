#!/usr/bin/env bash

set -euo pipefail
set -x

cd "$(dirname "$0")/.."

TARGET="${LLG_WASM_PY_TARGET:-pyodide}"

if [[ "$TARGET" == "wasm32-wasip1" ]]; then
    if ! command -v python >/dev/null 2>&1; then
        echo "python is required"
        exit 1
    fi

    python -m pip install --upgrade maturin
    rustup target add "$TARGET"

    python -m maturin build \
        --release \
        --target "$TARGET" \
        --compatibility off \
        --out target/wasm-wheels

    echo "Built wasm wheel(s) in target/wasm-wheels"
    exit 0
fi

if [[ "$TARGET" != "pyodide" && "$TARGET" != "wasm32-unknown-emscripten" ]]; then
    echo "Unsupported LLG_WASM_PY_TARGET: $TARGET"
    echo "Use one of: pyodide, wasm32-unknown-emscripten, wasm32-wasip1"
    exit 1
fi

PYODIDE_OUT_DIR="${LLG_PYODIDE_WHEEL_OUT_DIR:-target/pyodide-wheels}"
PYODIDE_XBUILDENV_VERSION="${LLG_PYODIDE_XBUILDENV_VERSION:-0.29.3}"

if [[ -n "${LLG_PYODIDE_PYTHON_BIN:-}" ]]; then
    PY_CMD=("${LLG_PYODIDE_PYTHON_BIN}")
elif command -v python >/dev/null 2>&1 && python - <<'PY'
import sys
raise SystemExit(0 if sys.version_info[:2] == (3, 13) else 1)
PY
then
    PY_CMD=(python)
elif command -v mise >/dev/null 2>&1; then
    PYODIDE_PYTHON_VERSION="${LLG_PYODIDE_PYTHON_VERSION:-3.13.2}"
    mise exec "python@${PYODIDE_PYTHON_VERSION}" -- python -V >/dev/null
    PYODIDE_PYTHON_DIR="$(mise where "python@${PYODIDE_PYTHON_VERSION}")"
    PY_CMD=("$PYODIDE_PYTHON_DIR/bin/python")
else
    echo "Pyodide build requires Python 3.13."
    echo "Install Python 3.13 and set LLG_PYODIDE_PYTHON_BIN, or install mise."
    exit 1
fi

run_py() {
    "${PY_CMD[@]}" "$@"
}

run_py -m pip install --upgrade pip setuptools wheel maturin pyodide-build
run_py -m pyodide_cli xbuildenv install "$PYODIDE_XBUILDENV_VERSION"
run_py -m pyodide_cli xbuildenv use "$PYODIDE_XBUILDENV_VERSION"

PYODIDE_ROOT="$(run_py -m pyodide_cli config get pyodide_root)"
XBUILDENV_ROOT="$(dirname "$(dirname "$PYODIDE_ROOT")")"
EMSDK_DIR="${LLG_PYODIDE_EMSDK_DIR:-$XBUILDENV_ROOT/emsdk}"
EMSCRIPTEN_VERSION="$(run_py -m pyodide_cli config get emscripten_version)"

EMCC_VERSION_OUTPUT="$(
    EMSDK="$EMSDK_DIR" PATH="$EMSDK_DIR:$EMSDK_DIR/upstream/emscripten:$PATH" emcc -v 2>&1 || true
)"

if [[ ! -x "$EMSDK_DIR/upstream/emscripten/emcc" ]] || [[ "$EMCC_VERSION_OUTPUT" != *"$EMSCRIPTEN_VERSION"* ]]; then
    run_py -m pyodide_cli xbuildenv install-emscripten
fi

RUST_TOOLCHAIN="$(run_py -m pyodide_cli config get rust_toolchain)"
RUST_EMSCRIPTEN_TARGET_URL="$(run_py -m pyodide_cli config get rust_emscripten_target_url)"

rustup toolchain install "$RUST_TOOLCHAIN"

if [[ -n "$RUST_EMSCRIPTEN_TARGET_URL" ]]; then
    RUSTC_PATH="$(rustup which --toolchain "$RUST_TOOLCHAIN" rustc)"
    TOOLCHAIN_ROOT="$(dirname "$(dirname "$RUSTC_PATH")")"
    RUSTLIB_DIR="$TOOLCHAIN_ROOT/lib/rustlib"
    INSTALL_TOKEN="$RUSTLIB_DIR/wasm32-unknown-emscripten_install-url.txt"
    if [[ ! -f "$INSTALL_TOKEN" ]] || [[ "$(cat "$INSTALL_TOKEN")" != "$RUST_EMSCRIPTEN_TARGET_URL" ]]; then
        rm -rf "$RUSTLIB_DIR/wasm32-unknown-emscripten"
        curl -fsSL "$RUST_EMSCRIPTEN_TARGET_URL" | tar -xj -C "$RUSTLIB_DIR"
        printf "%s" "$RUST_EMSCRIPTEN_TARGET_URL" > "$INSTALL_TOKEN"
    fi
else
    rustup target add wasm32-unknown-emscripten --toolchain "$RUST_TOOLCHAIN"
fi

mkdir -p "$PYODIDE_OUT_DIR"

PATH="$EMSDK_DIR:$EMSDK_DIR/upstream/emscripten:$PATH" \
EMSDK="$EMSDK_DIR" \
RUSTUP_TOOLCHAIN="$RUST_TOOLCHAIN" \
run_py -m pyodide_cli build . -o "$PYODIDE_OUT_DIR"

if ! compgen -G "$PYODIDE_OUT_DIR/*pyodide*_wasm32.whl" >/dev/null; then
    echo "No pyodide wheel produced in $PYODIDE_OUT_DIR"
    exit 1
fi

echo "Built pyodide wheel(s) in $PYODIDE_OUT_DIR"
