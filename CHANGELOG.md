# Changelog

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
