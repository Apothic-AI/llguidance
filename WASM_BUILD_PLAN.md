# llguidance WASM + WASM Python Wheel Plan

## Goal
Produce two deliverables from this repository:
1. A WASM build of the core `llguidance` engine.
2. A WASM Python wheel.

## Implementation status
- Core WASM build implemented and validated via `./scripts/build-wasm-core.sh`.
- WASM Python wheel build implemented and validated via `./scripts/build-wasm-wheel.sh` targeting `wasm32-wasip1`.
- CI jobs added for both.
- Note: `wasm32-unknown-emscripten` wheel build is currently not reproducible in this repo/toolchain combination (link/export failures), so CI uses WASI for now.

## What the codebase already supports

### Core crate (`parser`)
- `parser/Cargo.toml` defines a `wasm` feature (`instant`-based timing).
- `parser/src/lib.rs` already switches `Instant` for WASM via `#[cfg(feature = "wasm")]`.
- `parser/src/ffi.rs` already exports a complete C ABI (`llg_*` `extern "C"` functions), which can be exported from a `.wasm` module.

### Python extension crate (`python_ext`)
- Python packaging uses `maturin` + `pyo3` (`pyproject.toml`, `python_ext/Cargo.toml`).
- Local compile checks show `wasm32-wasip1` wheel builds reproducibly with `maturin`.

### Current gaps
- No WASM build scripts or CI jobs exist (`.github/workflows/*` only build native wheels and native Rust).
- Core `llguidance` default features are not WASM-`unknown-unknown` safe:
  - `cargo check -p llguidance --target wasm32-unknown-unknown --features wasm` fails in `getrandom`.
  - `cargo check -p llguidance --target wasm32-unknown-unknown --no-default-features --features wasm` succeeds.
  - `cargo check -p llguidance --target wasm32-unknown-unknown --no-default-features --features wasm,lark` succeeds.
- `python_ext/src/llmatcher.rs` uses `std::thread::available_parallelism().unwrap()`; this is a likely runtime panic risk on some WASM runtimes.

## Target build strategy

### Deliverable A: core WASM module
- Target: `wasm32-unknown-unknown`.
- Feature profile: `--no-default-features --features wasm,lark` (avoid current default feature set that pulls `getrandom` path).
- Output: `target/wasm32-unknown-unknown/release/llguidance.wasm`.

### Deliverable B: WASM Python wheel
- Target: `wasm32-wasip1`.
- Build backend: keep `maturin`/`pyo3`, with a WASM-specific build script and CI job.
- Artifact: WASI wheel from `target/wasm-wheels`.

## Implementation plan

## Phase 1: lock in reproducible WASM commands
1. Add `scripts/build-wasm-core.sh` with:
   - `rustup target add wasm32-unknown-unknown`
   - `cargo build -p llguidance --release --target wasm32-unknown-unknown --no-default-features --features wasm,lark`
2. Add `scripts/build-wasm-wheel.sh` with:
   - toolchain checks for Python and `maturin`
   - `rustup target add wasm32-wasip1`
   - `maturin build --release --target wasm32-wasip1`
3. Document both in `README.md`.

## Phase 2: make runtime behavior WASM-safe
1. In `python_ext/src/llmatcher.rs`, replace:
   - `std::thread::available_parallelism().unwrap().get()`
   with:
   - fallback-safe logic (`unwrap_or(1)` style).
2. If needed, add a WASM cfg path forcing `LLExecutor` to single-thread defaults.

## Phase 3: CI integration
1. Extend `.github/workflows/rust.yml`:
   - Add a job that checks core WASM build command.
2. Extend `.github/workflows/wheels.yml` (or add a dedicated workflow):
   - Add WASI wheel build job.
   - Upload wheel artifact separately (distinct artifact name).
3. Keep existing native wheel jobs unchanged.

## Phase 4: validation and release criteria
1. Core WASM validation:
   - Build succeeds.
   - `.wasm` exports include expected `llg_*` symbols.
2. Python WASM validation:
   - Wheel builds end-to-end for `wasm32-wasip1`.
   - Artifact is emitted to `target/wasm-wheels`.
3. Regression validation:
   - Existing native Rust and native Python jobs still pass.

## Open decisions to resolve during implementation
1. Feature policy for core WASM:
   - Keep current `--no-default-features --features wasm,lark` command-based profile, or add an explicit Cargo feature alias for WASM builds.
2. Wheel build command details:
   - Exact `maturin` flags/compatibility tags for your target runtime policy (Pyodide version and wheel tagging rules).
3. Distribution model for core WASM:
   - Publish only raw `.wasm`, or ship a JS wrapper package around exported ABI.

## Definition of done
- One command builds core `llguidance.wasm` reproducibly.
- One command builds the WASM Python wheel reproducibly.
- CI checks both paths.
- README documents both workflows and toolchain prerequisites.
