# Pyodide Wheel Issue and Resolution

## Summary
The prior Pyodide wheel attempt failed because it used raw `maturin` on an ad-hoc emscripten setup. Pyodide needs a coordinated toolchain bundle (Python, emsdk, Rust nightly, and a custom emscripten Rust sysroot).

This branch now builds a working Pyodide-compatible wheel.

## Root causes
1. The build was running on Python 3.14, but available Pyodide xbuildenv releases currently match Python 3.13 for this flow.
2. `pyodide` injects `-Z` Rust flags, but the environment had `RUSTUP_TOOLCHAIN=1.93.0` forced globally, so stable rustc was used.
3. The codebase declared `rust-version = 1.87`, while Pyodide’s configured Rust toolchain is `nightly-2025-02-01` (`1.86.0-nightly`).
4. The code used `is_multiple_of`, which is not available on that older Rust toolchain.

## What changed
1. `scripts/build-wasm-wheel.sh` now supports a Pyodide build path (default target):
   - Uses `pyodide build` via `python -m pyodide_cli`.
   - Installs/uses Pyodide xbuildenv and emsdk.
   - Installs the Rust toolchain from `pyodide config`.
   - Installs the Pyodide-provided `wasm32-unknown-emscripten` sysroot when configured.
   - Forces `RUSTUP_TOOLCHAIN` only for the build command.
2. Workspace MSRV was lowered to `1.86` (`Cargo.toml`) to match Pyodide’s toolchain.
3. `is_multiple_of` call sites were replaced with equivalent arithmetic checks compatible with Rust 1.86.

## Result
A working wheel is produced:
- `target/pyodide-wheels/llguidance-1.5.0-cp39-abi3-pyodide_2025_0_wasm32.whl`

This wheel carries the Pyodide platform tag and is compatible with Pyodide’s emscripten ABI.
