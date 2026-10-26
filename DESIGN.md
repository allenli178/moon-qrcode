# MoonQR Design

Condensed implementation design for the encoder described in `dev.md`.
Standard: ISO/IEC 18004:2015 Model 2, encoding only.

## Goals

- One MoonBit codebase for wasm, wasm-gc, JS and native.
- Zero third-party dependencies in the encoder, renderers and flat API.
- A finished, immutable `QrCode`; no half-built matrix can leave the core.
- Correctness demonstrated by reference cross-checks, property tests,
  machine-checked capacity contracts and bit-identical output on every backend.

Non-goals: decoding, raster export, styling, Micro QR, Kanji, ECI, Structured
Append (see README).

## Layers

```
cmd/moonqr            CLI: argument parsing, stdin, JSON, file output
npm                   typed ESM wrapper over the JS build (Node + tsc tests)
js                    flat Uint8Array ABI + ESM / wasm-gc link exports
render                ASCII / half-height / SVG (no encoding logic)
content               payload templates (no encoding logic)
core                  segments -> bit stream -> RS -> matrix -> mask -> QrCode
core/capacity_model   capacity arithmetic with `moon prove` contracts
benchmarks            native timing harness
```

Hard rules preserved from the PRD:

- `core` imports only `core/capacity_model` and the standard library; it never
  imports `render`, `content`, `js` or the CLI.
- Rendering and templates only consume `QrCode`; they cannot construct one.
- No IO in any library layer. The CLI owns filesystem and process access.
- `QrCode` has private fields and is built only by `encode`.

## Core modules

| File | Responsibility |
| --- | --- |
| `types.mbt` | `EcLevel`, `Mode`, `Mask`, `Version` (smart constructor), `QrCode` |
| `capacity.mbt` | delegation to `capacity_model` plus EC block tables |
| `capacity_model/` | proof-enabled arithmetic: total codewords, count-field widths, mode capacities |
| `segments.mbt` | greedy runs, optimal DP segmentation, header bits, data-bit accounting, bit emission |
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
   In auto mode `encode` instead uses `optimal_segments`, a six-state dynamic
   program (numeric count mod 3, alphanumeric count mod 2, byte) run once per
   version group (1–9, 10–26, 27–40); byte segments keep their exact `Bytes`.
2. `choose_version_optimal` computes `bits_needed` for the DP result and
   selects the first version that fits `data_capacity_bits(version, ec)`.
   A forced `mode` uses greedy `split_segments` plus `choose_version`, so
   explicit-mode output stays deterministic.
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

## Rendering

`to_svg` emits one background `<rect>` and one `<path>` whose subpaths are
horizontal dark runs (`M{x} {y}h{run}v1h-{run}`). This keeps large symbols
compact without changing the matrix. `to_ascii` and `to_ascii_half` are pure
string builders over `QrCode`.

## Capacity proofs

`core/capacity_model` is a separate `proof_enabled` package so contracts can
be attached without changing the public encoder modules. `moon prove
core/capacity_model` discharges four goals with Z3:

| Function | Contract |
| --- | --- |
| `total_codewords` | `1 <= version <= 40` → `26 <= result <= 3706` |
| `char_count_bits` | `1 <= version <= 40` → `8 <= result <= 16` |
| `numeric_capacity` | `0 <= bits <= 65536` → `result * 10 <= bits * 3` |
| `byte_capacity` | `0 <= bits <= 65536` → `result == bits / 8` |

`alphanumeric_capacity` carries no postcondition and is covered by capacity
tests and the reference fuzz cross-check. `core/capacity.mbt` delegates all
five helpers to the proved package, so the shipped arithmetic is the same code
that Z3 checks.

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
- Segmentation preserves the input exactly; byte mode encodes UTF-8 bytes, and
  `Segment::from_bytes` keeps arbitrary bytes untouched.
- Optimal segmentation never costs more bits than the greedy split and
  reconstructs the input exactly; exhaustive tests cover short strings across
  all three version groups.
- SVG run merging emits every dark module exactly once; the ZXing harness
  parses the resulting `<path>`.
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
- `encode_to_modules(text, ...)` and `encode_bytes_to_modules(data, ...)` for
  structured JS hosts.
- `encode_flat_buffer(text, ec_level, min_version, max_version, mask?)` and
  `encode_bytes_flat_buffer(...)` returning `Bytes` (mapped to `Uint8Array` by
  the JS backend) laid out as `[size_hi, size_lo, version, mask, modules...]`.
- `flat_error_message(error)` for a readable diagnostic on the JS side.

`js/moon.pkg` enables ESM output for the JS target and marks both flat-buffer
functions as wasm-gc exports. Optional `mask` arguments cross the JS ABI as
unboxed options. Returning a flat buffer avoids nested arrays and JSON at the
host boundary. The raw linear-memory pointer/free API from the PRD is not
exposed; MoonBit's GC-managed `Bytes` return value gives JS hosts a
`Uint8Array` without manual lifetimes.

`npm/` wraps the JS ESM build in `encode`, `encodeBytes`, `encodeToBytes` and
`QrCodeError`, with TypeScript declarations. `npm test` builds
`dist/moonbit.js`, runs the Node tests and type-checks positive/negative usage.
The package is marked `private: true` and is not published to the registry.

## Verification

- 88 unit and README tests run on wasm, wasm-gc, JS and native, plus seven
  native benchmarks (`moon test` reports 95 entries).
- 72 byte-mode, 32 alphanumeric and 8 numeric matrix digests (112 total) are
  pinned from the Python `qrcode` reference; selected matrices are compared
  module-by-module.
- `tools/fuzz/verify.py` cross-checks 203 forced version/EC/mode/mask cases
  against Python `qrcode` 8.2, including UTF-8, every mask and a payload that
  starts with a dash (passed after `--`).
- `moon prove core/capacity_model` proves four contracts with Z3.
- BCH/GF/RS tests use polynomial identities and published constants, not only
  snapshots.
- Capacity monotonicity, EC ordering, block accounting, exact-capacity
  boundaries, greedy/optimal segmentation and error paths are asserted.
- Core coverage is 95.5%, gated at 90% in CI.
- `tools/zxing/verify.js` decodes twelve generated symbols with the ZXing
  reference implementation.
- `tools/cli/smoke.py` covers 17 CLI behaviors; the npm wrapper adds 10 Node
  tests plus positive/negative TypeScript checks.
- CI runs the test matrix on Ubuntu and macOS, plus size budgets, ZXing,
  coverage, npm, fuzz, benchmark and proof jobs.

## Deviations from `dev.md`

| PRD item | Implementation |
| --- | --- |
| `moon.mod.json` / `moon.pkg.json` | modern `moon.mod` / `moon.pkg` files |
| `tests/` directory | blackbox tests live next to each package (`*_test.mbt`) |
| `verify/` with `moon prove` | implemented as the proof-enabled `core/capacity_model` package; remaining invariants are covered by property and reference tests |
| manual wasm pointer ABI | flat `Bytes`/`Uint8Array` ABI with GC-managed lifetime |
| npm-ready JS entry | typed ESM wrapper in `npm/` (Node + `tsc` tests), marked private and unpublished |
| zero dependencies | library packages are stdlib-only; the CLI depends on `moonbitlang/x` for fs/sys |
| ZXing CI playback | `tools/zxing/verify.js` decodes generated symbols in CI; physical-camera checks remain manual |
| benchmark suite (NFR-4) | `benchmarks/` runs 7 native benchmarks; release size budgets are enforced in CI |
