# MoonQR Design

Condensed implementation design for the encoder described in `dev.md`.
Standard: ISO/IEC 18004:2015 Model 2, encoding only.

## Goals

- One MoonBit codebase for wasm-gc, JS and native.
- Zero third-party dependencies in the encoder, renderers and flat API.
- A finished, immutable `QrCode`; no half-built matrix can leave the core.
- Correctness demonstrated by reference cross-checks, property tests and
  bit-identical output on every backend.

Non-goals: decoding, raster export, styling, Micro QR, Kanji, ECI, Structured
Append (see README).

## Layers

```
cmd/moonqr   CLI: argument parsing, file output
js           flat Uint8Array ABI + ESM / wasm-gc link exports
render       ASCII / half-height / SVG (no encoding logic)
content      payload templates (no encoding logic)
core         segments -> bit stream -> RS -> matrix -> mask -> QrCode
```

Hard rules preserved from the PRD:

- `core` never imports `render`, `content`, `js` or the CLI.
- Rendering and templates only consume `QrCode`; they cannot construct one.
- No IO in any library layer. The CLI owns filesystem and process access.
- `QrCode` has private fields and is built only by `encode`.

## Core modules

| File | Responsibility |
| --- | --- |
| `types.mbt` | `EcLevel`, `Mode`, `Mask`, `Version` (smart constructor), `QrCode` |
| `capacity.mbt` | total/data/ECC codewords, block counts, character capacity |
| `segments.mbt` | greedy class runs, header bits, data-bit accounting, bit emission |
| `bitbuf.mbt` | mode/count/data fields, terminator, byte alignment, `0xEC`/`0x11` padding |
| `rs.mbt` | GF(2^8) tables (0x11D), generator polynomials, RS parity |
| `bch.mbt` | BCH(15,5) format bits (0x537, mask 0x5412), BCH(18,6) version bits (0x1F25) |
| `matrix.mbt` | function patterns, alignment centers, zig-zag placement, masks, format/version modules |
| `penalty.mbt` | Annex J rules N1=3, N2=3, N3=40, N4=10 |
| `encode.mbt` | version choice, block interleaving, mask selection, public `encode` |
| `error.mbt` | checked `QrError` with actionable messages |

## Pipeline

1. `split_segments(text, mode?)` validates and splits into greedy Numeric /
   Alphanumeric / Byte runs. Short numeric (≤2) and alphanumeric (≤4) runs
   adjacent to a byte run are absorbed into it; adjacent byte runs merge.
2. `choose_version` computes `bits_needed` for each candidate and selects the
   first that fits `data_capacity_bits(version, ec)`.
3. `BitBuffer` writes the 4-bit mode, character-count field, payload, a
   terminator of at most four bits, zero alignment, then alternating
   `0xEC`/`0x11` pad bytes up to the data-codeword capacity.
4. `interleave_blocks` splits data codewords into short/long RS blocks, appends
   per-block parity, and interleaves data then parity.
5. `build_matrix` places finders/separators, timing, alignment patterns, the
   dark module, reserves format/version areas, and fills codewords in zig-zag
   order.
6. Without an explicit mask, all eight masks are applied to a fresh copy,
   scored, and the lowest penalty wins. Format/version bits are written last.

## Invariants and checks

- `Version::new` is the only public constructor and enforces `1..40`;
  `encode` rejects invalid `min_version`/`max_version` ranges.
- Capacity tables are derived from the ISO raw-module formula, so data + ECC ×
  blocks always equals total codewords. Tests assert this for all 40 versions
  and all four EC levels.
- `BitBuffer::pad_to` raises `Internal` rather than silently truncating or
  overflowing capacity; the final bit length must equal capacity.
- `rs_encode` returns exactly `nsym` parity bytes and handles `nsym = 0`.
- Format information is divisible by `0x537` after unmasking and has the
  correct top five bits; version information is divisible by `0x1F25`.
- Segmentation preserves the input exactly; byte mode encodes UTF-8 bytes.
- Mask application is its own inverse; tables and outputs are deterministic.
- SVG colors reject markup and `url(...)`; invalid colors raise
  `InvalidColor`.

## Error model

`QrError` is a checked `pub(all) suberror`:

- `EmptyInput`
- `DataTooLong(needed, capacity, version, ec_level)`
- `InvalidVersion(Int)`
- `InvalidCharacter(char, mode)`
- `InvalidColor(String)`
- `Internal(String)` for violated invariants (a bug, not user input)

`QrError::message()` includes the numbers needed to fix the input, for example
`data needs 312 bits but V5-H holds 232 bits; use a higher version, a lower EC
level, or shorten the input`.

## JS / wasm ABI

`js/flat.mbt` exposes:

- `FlatQr` with `size`, `version`, `ec_level`, `mask`, `data` (`Bytes`) and
  `module_at`.
- `encode_flat_buffer(text, ec_level, min_version, max_version)` returning
  `Bytes` (mapped to `Uint8Array` by the JS backend) laid out as
  `[size_hi, size_lo, version, mask, modules...]`.

`js/moon.pkg` enables ESM output for the JS target and marks
`encode_flat_buffer` as a wasm-gc export. Returning a flat buffer avoids
nested arrays and JSON at the host boundary. The raw linear-memory
pointer/free API from the PRD is not exposed; MoonBit's GC-managed `Bytes`
return value gives JS hosts a `Uint8Array` without manual lifetimes.

## Verification

- 71 tests run on wasm, wasm-gc, JS and native.
- 72 byte-mode, 32 alphanumeric and 8 numeric matrix digests (112 total) are
  pinned from the Python `qrcode` reference; selected matrices are compared
  module-by-module.
- BCH/GF/RS tests use polynomial identities and published constants, not only
  snapshots.
- Capacity monotonicity, EC ordering, block accounting, exact-capacity
  boundaries and error paths are asserted.
- Core coverage is above 90%.
- `tools/zxing/verify.js` decodes twelve generated symbols with the ZXing
  reference implementation; CI runs the decode check alongside the test suite,
  size budgets and coverage.

## Deviations from `dev.md`

| PRD item | Implementation |
| --- | --- |
| `moon.mod.json` / `moon.pkg.json` | modern `moon.mod` / `moon.pkg` files |
| `tests/` directory | blackbox tests live next to each package (`*_test.mbt`) |
| `verify/` with `moon prove` | deferred; property tests cover the same invariants |
| manual wasm pointer ABI | flat `Bytes`/`Uint8Array` ABI with GC-managed lifetime |
| npm-ready JS entry | generated ESM + `.d.ts`; npm packaging is roadmap |
| zero dependencies | library packages are stdlib-only; the CLI depends on `moonbitlang/x` for fs/sys |
| ZXing CI playback | `tools/zxing/verify.js` decodes generated symbols in CI; physical-camera checks remain manual |
| benchmark suite (NFR-4) | not yet added; artifact sizes were measured manually |
