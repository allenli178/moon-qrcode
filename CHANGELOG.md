# Changelog

## 0.2.0 — 2026-10-26

Capability release: complete payload input, compact SVG, a fuller CLI and JS
distribution, and machine-checked capacity contracts.

### Added

- `encode_bytes` for arbitrary binary payloads; `Segment::from_bytes` keeps
  non-UTF-8 bytes exactly.
- `encode_segments` for caller-composed segment lists.
- Optimal dynamic-programming segmentation for auto mode (six states across
  version groups), with exhaustive optimality tests; forced modes keep the
  greedy split.
- `-f json` / `--json` CLI output, stdin payloads (`-`), a `--` option
  terminator, the `-V` version alias and stderr diagnostics.
- `tools/cli/smoke.py` with 17 CLI behavior checks.
- Typed ESM/npm wrapper (`npm/`) with `encode`, `encodeBytes`, `encodeToBytes`,
  `QrCodeError`, TypeScript declarations, Node tests and pack validation.
- Flat JS ABI additions: `encode_bytes_to_modules`,
  `encode_bytes_flat_buffer`, optional forced masks and `flat_error_message`.
- Seven native benchmarks (`benchmarks/`) covering versions 1/10/40, auto
  mixed payloads, SVG and half-height rendering.
- Proof-enabled `core/capacity_model` with four `moon prove` contracts checked
  by Z3.
- `tools/fuzz/verify.py`, a reference cross-check against Python `qrcode` 8.2
  covering 203 matrices.
- Multi-OS CI (Ubuntu + macOS) with size, ZXing, coverage, npm, fuzz,
  benchmark and formal-proof jobs; a shared `setup-moonbit` action caches the
  package registry.

### Changed

- SVG output now merges horizontal dark runs into a single `<path>` instead of
  emitting one `<rect>` per module.
- Capacity helpers delegate to the proved `core/capacity_model` package.
- CLI diagnostics go to stderr; `--cli-version` gains the `-V` alias.
- Module and npm wrapper versions bumped to 0.2.0.

### Verification

- 88 unit and README tests on wasm-gc, wasm, JS and native.
- 112 pinned reference matrix digests.
- 203 Python `qrcode` cross-check matrices, 12 ZXing decodes, 17 CLI smoke
  tests, and 10 npm tests plus TypeScript checks.
- Core coverage 95.5%; release artifacts stay within the CI size budgets.

## 0.1.0 — 2026-10-26

Initial release.

- ISO/IEC 18004 Model 2 encoder for versions 1–40 and EC levels L/M/Q/H.
- Numeric, alphanumeric and UTF-8 byte modes with greedy auto-segmentation.
- Bit buffer with terminator, alignment and `0xEC`/`0x11` padding.
- Reed–Solomon over GF(2^8) (0x11D) with block splitting and interleaving.
- BCH format and version information.
- Function patterns, zig-zag placement, eight masks and Annex J penalty
  selection.
- Immutable `QrCode` with `get`, `modules` and `to_bytes`.
- ASCII, half-height and SVG renderers with quiet zone, scaling and color
  validation.
- Payload templates for URL, WiFi, tel, mailto, SMS, geo, vCard and text.
- Flat `Uint8Array` ABI with ESM and wasm-gc link exports.
- Native CLI (`cmd/moonqr`) with version/EC/mode/mask/format options.
- 71 tests, with matrices cross-checked against the Python `qrcode`
  reference and identical results on wasm, wasm-gc, JS and native.
- ZXing decode verification harness (`tools/zxing`) covering all EC levels,
  UTF-8, forced masks/versions and long payloads.
- GitHub Actions CI for formatting, all-backend checks and tests, artifact
  size budgets, coverage and ZXing decoding.
