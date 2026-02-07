# Pyodide Wheel Build Failure Report

## Summary
The attempt to produce a Pyodide-compatible wheel (`wasm32-unknown-emscripten`) failed due to multiple toolchain and linking issues in the current `pyo3` + `maturin` + emscripten path.

A WASM wheel was successfully produced for `wasm32-wasip1`, but that wheel is **not** Pyodide-compatible.

## What failed

## 1. Initial toolchain prerequisite failure
- `scripts/build-wasm-wheel.sh` initially failed because `emcc` was not available.
- This was resolved by installing and activating emsdk.

## 2. `maturin` requires nightly-only rust flag for emscripten flow
- `maturin` passed `-Z link-native-libraries=no`, which fails on stable Rust.
- Error observed:
  - `the option 'Z' is only accepted on the nightly compiler`

## 3. `cdylib` target support regression/behavior change on latest nightly
- With latest nightly, build failed early with:
  - `cannot produce cdylib ... target wasm32-unknown-emscripten`
- This behavior was confirmed independently with a minimal test crate.

## 4. Older toolchain progressed, but emscripten link failed (`main` missing)
- Pinning to an older toolchain (`nightly-2025-09-20`) allowed compilation to proceed further.
- Link then failed with:
  - `undefined symbol: main`
- This indicates emscripten was still linking as an executable-style module in that path.

## 5. Side-module path progressed, but export handling failed
- With side-module flags, linking advanced but then failed with invalid export names:
  - `emcc: error: invalid export name: _ZN...`
- This suggests rust-mangled/internal symbols were being treated as C exports by the emscripten/maturin export flow in this configuration.

## 6. Dependency crate-type conflict amplified emscripten linking issues
- `parser` (`llguidance`) originally exposed `cdylib` in crate types.
- As a dependency of `llguidance_py`, this contributed to problematic wasm linking behavior.
- We changed it to `["staticlib", "rlib"]` and forced `cdylib` only for the standalone core wasm build path.
- This improved correctness for the WASI workflow but did not fully unblock emscripten/Pyodide wheel generation.

## Current status
- `wasm32-wasip1` wheel build works and is reproducible.
- `wasm32-unknown-emscripten` wheel build remains broken in current setup.
- Therefore, no Pyodide-compatible wheel is currently produced.

## Practical implication
The existing wheel artifact (`cp39-abi3-any`) built for `wasm32-wasip1` will not load in Pyodide, because Pyodide expects emscripten ABI/runtime compatibility.

