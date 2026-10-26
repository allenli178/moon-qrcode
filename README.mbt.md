# MoonQR

[![CI](https://github.com/allenli178/moon-qrcode/actions/workflows/ci.yml/badge.svg)](https://github.com/allenli178/moon-qrcode/actions/workflows/ci.yml)

English | [中文](./README.zh-CN.md)

A pure-MoonBit QR Code **encoder** for ISO/IEC 18004 Model 2 symbols. The
encoder produces the finished module matrix; its core, renderers and payload
templates are dependency-free, and a thin CLI is included on top.

- Versions 1–40, error-correction levels L / M / Q / H
- Numeric, alphanumeric and UTF-8 byte segments with greedy auto-splitting
- Automatic version selection and all eight data masks with Annex J scoring
- Reed–Solomon over GF(2<sup>8</sup>) (0x11D), BCH format/version information
- Immutable `QrCode` matrix (`size`, `get`, `modules`, `to_bytes`)
- ASCII, half-height and SVG renderers
- Payload templates: URL, WiFi, tel, mailto, SMS, geo, vCard and text
- Flat `Uint8Array` ABI for JS/wasm hosts; native CLI

## Install

```bash
moon add allenli178/moon-qrcode
```

Requires MoonBit `0.1.20261020` or newer.

## Quick start

```mbt check
///|
test "README quick start" {
  let qr = @moon-qrcode.encode("HELLO WORLD", ec_level=@moon-qrcode.EcLevel::M)
  assert_eq(qr.version().value(), 1)
  assert_eq(qr.size(), 21)
  assert_true(qr.get(0, 0))
  let svg = @moon-qrcode.to_svg(qr, quiet_zone=4, module_size=4)
  assert_true(svg.contains("<svg"))
}
```

`encode` picks the smallest version in `min_version..max_version` that fits the
selected EC level, then picks the mask with the lowest penalty.

| Option | Default | Meaning |
| --- | --- | --- |
| `text` | — | payload string (UTF-8 in byte mode) |
| `ec_level` | `M` | error-correction level |
| `min_version` / `max_version` | `1` / `40` | version search range |
| `mode` | auto | force `Numeric`, `Alphanumeric` or `Byte` |
| `mask` | auto | force a mask `M0`–`M7` |

### Reading the matrix

| Function | Result |
| --- | --- |
| `size()` | side length in modules (`4 * version + 17`) |
| `get(row, col)` | `Bool` for one module |
| `modules()` | row-major `Array[Bool]` copy |
| `to_bytes()` | row-major `Array[Byte]`, `1` = dark |
| `version()` / `ec_level()` / `mask()` | metadata |

Errors are checked: `DataTooLong` carries the needed bits, capacity, version
and EC level, and `QrError::message()` renders an actionable diagnostic.

## Rendering

```mbt check
///|
test "README rendering" {
  let qr = @moon-qrcode.encode("https://moonbitlang.com")
  let ascii = @moon-qrcode.to_ascii(qr, quiet_zone=2)
  let half = @moon-qrcode.to_ascii_half(qr)
  assert_true(ascii.length() > 0)
  assert_true(half.length() > 0)
  let custom = @moon-qrcode.to_svg(qr, dark="navy", light="#ffffff")
  assert_true(custom.contains("fill=\"navy\""))
}
```

- `to_ascii(qr, quiet_zone?, scale?)` uses double-width blocks; `scale`
  repeats each module.
- `to_ascii_half(qr, quiet_zone?)` packs two module rows per terminal row.
- `to_svg(qr, quiet_zone?, module_size?, dark?, light?)` returns a complete
  SVG document. Colors are validated and `url(...)` is rejected; invalid
  colors raise `QrError::InvalidColor`.

## Payload templates

```mbt check
///|
test "README templates" {
  let wifi = @moon-qrcode.Content::wifi("Cafe", "latte")
  assert_eq(wifi.to_text(), "WIFI:T:WPA;S:Cafe;P:latte;;")
  let card = @moon-qrcode.Content::vcard(
    "Ada Lovelace",
    email="ada@example.com",
  )
  let qr = @moon-qrcode.encode_content(card, ec_level=@moon-qrcode.EcLevel::H)
  assert_true(qr.size() >= 21)
}
```

Available constructors: `Content::wifi(ssid, password, auth?)`,
`Content::mailto(address, subject?, body?)`, `Content::sms(number, message?)`,
`Content::tel(number)`, `Content::geo(lat, lng)`,
`Content::vcard(name, phone?, email?, org?)`, plus `Text` and `Url`.
`to_text()` serializes a payload; `encode_content()` serializes and encodes it.

## CLI

```bash
# run from the module checkout
moon run cmd/moonqr --target native -- "HELLO WORLD" -l H -o hello.svg

# release binary: _build/native/release/build/cmd/moonqr/moonqr.exe
moon build cmd/moonqr --target native --release
```

```
USAGE:
  moonqr <payload> [options]

  -l, --level <L|M|Q|H>      error correction level (default M)
  -v, --version <1..40>      force an explicit version
      --min-version <n>      smallest version considered
      --max-version <n>      largest version considered
  -m, --mode <name>          numeric | alphanumeric | byte (default auto)
      --mask <0..7>          force a mask pattern
  -q, -qz, --quiet-zone <n>  quiet zone width in modules (default 4)
  -s, --scale <n>            ASCII scale factor (default 1)
      --module-size <n>      SVG module size in pixels (default 4)
  -f, --format <name>        ascii | half | svg (default: by output extension)
  -o, --output <path>        write to a file instead of stdout
      --svg / --half         format shorthands
      --dark / --light       SVG colors
```

Examples:

```bash
moonqr "https://moonbitlang.com" --svg -o site.svg
moonqr "0123456789" -v 2 -m numeric -s 2
moonqr "payload" --min-version 5 --max-version 10 -l Q -f half
```

## JS / wasm flat API

The `js` package exports a primitive-typed buffer ABI so hosts never pay for
JSON or nested arrays. Build it with:

```bash
moon build js --target js --release       # _build/js/release/build/js/js.js + .d.ts
moon build js --target wasm-gc --release  # _build/wasm-gc/release/build/js/js.wasm
```

```js
import { encode_flat_buffer } from "./_build/js/release/build/js/js.js";

// ec_level: 0=L, 1=M, 2=Q, 3=H
const result = encode_flat_buffer("HELLO WORLD", 1, 1, 40);
if (result.$tag === 1) {
  const buf = result._0;                  // Uint8Array
  const size = (buf[0] << 8) | buf[1];    // side length in modules
  const version = buf[2];
  const mask = buf[3];
  const modules = buf.subarray(4);        // size * size bytes, 1 = dark
}
```

Buffer layout: `[size_hi, size_lo, version, mask, modules...]`. The JS
binding type-checks as `Uint8Array`; errors surface as `Result` (`$tag === 0`).

Measured artifact sizes (release, this repository):

| Artifact | Raw | gzip |
| --- | --- | --- |
| wasm-gc encoder + flat API (`js.wasm`) | 20.6 KB | 8.6 KB |
| JS ESM encoder + flat API (`js.js`) | 71.7 KB | 10.5 KB |
| native release CLI (`moonqr.exe`) | 353 KB | — |

## Correctness and testing

```bash
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
moon fmt --check && moon info

# ZXing decode check (Node 18+)
moon build cmd/moonqr --target native --release
npm ci --prefix tools/zxing
node tools/zxing/verify.js
```

- 71 tests across `core`, `render`, `content`, `js` and the root facade.
- Matrix digests are pinned from the Python `qrcode` reference implementation:
  72 byte-mode vectors across versions/EC levels/masks, 32 alphanumeric and
  8 numeric vectors (112 total), plus full-matrix snapshots.
- GF(2<sup>8</sup>), BCH divisibility/known values, RS parity vectors, capacity
  accounting, segment splitting, error paths and SVG/ASCII output are covered.
- The same test suite passes on wasm, wasm-gc, JS and native targets, so
  output is bit-identical across the four backends.
- Core coverage is above 90% (`moon coverage analyze`); remaining uncovered
  lines are defensive invariant checks and unreachable enum arms.
- Twelve generated symbols (all EC levels, UTF-8, forced masks and versions,
  long payloads, payload templates) decode correctly with the ZXing reference
  implementation; the check runs in CI.

Physical-camera tests on iOS/Android/WeChat are still manual; ZXing decoding
and matrix-level cross-checking are the automated gates.

## Scope

Implemented: Model 2 versions 1–40, L/M/Q/H, numeric/alphanumeric/byte, greedy
auto-segmentation, masks, renderers, templates, CLI, flat JS/wasm ABI.

Deliberately excluded: decoding, PNG/JPEG/PDF export, logos/styling, Micro QR,
Kanji mode, ECI and Structured Append. Formal `moon prove` contracts, a
benchmark suite, physical-camera automation and a published npm wrapper are
roadmap items; property tests stand in for proofs today.

## Project layout

```
core/      encoder: types, capacity, segments, bit buffer, RS, BCH, matrix, penalty
render/    ASCII and SVG renderers
content/   payload templates
js/        flat Uint8Array ABI + ESM/wasm-gc link exports
cmd/moonqr CLI
tools/zxing ZXing decode verification harness (Node)
```

`core`, `render`, `content` and `js` use only the MoonBit standard library.
The CLI adds `moonbitlang/x` for filesystem and process support.

## License

Apache-2.0.
