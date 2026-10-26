# MoonQR

[![CI](https://github.com/allenli178/moon-qrcode/actions/workflows/ci.yml/badge.svg)](https://github.com/allenli178/moon-qrcode/actions/workflows/ci.yml)

English | [中文](./README.zh-CN.md)

A pure-MoonBit QR Code **encoder** for ISO/IEC 18004 Model 2 symbols. The
encoder produces the finished module matrix; its core, renderers and payload
templates are dependency-free, and a thin CLI is included on top.

- Versions 1–40, error-correction levels L / M / Q / H
- Numeric, alphanumeric and UTF-8 byte segments with optimal
  dynamic-programming auto-segmentation
- Raw `Bytes` payloads and caller-composed segment lists
- Automatic version selection and all eight data masks with Annex J scoring
- Reed–Solomon over GF(2<sup>8</sup>) (0x11D), BCH format/version information
- Immutable `QrCode` matrix (`size`, `get`, `modules`, `to_bytes`)
- ASCII, half-height and SVG renderers; SVG merges dark runs into one `<path>`
- Payload templates: URL, WiFi, tel, mailto, SMS, geo, vCard and text
- Flat `Uint8Array` ABI, a typed ESM/npm wrapper and a native CLI with stdin
  and JSON output
- Machine-checked capacity contracts (`moon prove` + Z3) and a Python
  `qrcode` reference cross-check

## Install

```bash
moon add allenli178/moon-qrcode
```

Requires MoonBit `0.1.20261023` or newer.

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

### Raw bytes and custom segments

`encode_bytes` encodes arbitrary binary data as one Byte segment, preserving
bytes that are not valid UTF-8. `encode_segments` accepts a caller-composed
segment list and encodes it in order.

```mbt check
///|
test "README payload options" {
  let binary = @moon-qrcode.encode_bytes(
    b"\xff\x00\x80",
    ec_level=@moon-qrcode.EcLevel::L,
  )
  assert_eq(binary.version().value(), 1)
  let segments : Array[@moon-qrcode.Segment] = [
    @moon-qrcode.Segment::new(@moon-qrcode.Mode::Numeric, "12345"),
    @moon-qrcode.Segment::from_bytes(b"\xff\x00"),
  ]
  let qr = @moon-qrcode.encode_segments(
    segments,
    ec_level=@moon-qrcode.EcLevel::M,
  )
  assert_eq(qr.version().value(), 1)
}
```

In auto mode `encode` runs a dynamic-programming segmentation over all three
modes and all version groups, so mixed payloads get the cheapest encoding
rather than greedy class runs. Supplying `mode` keeps the deterministic greedy
split from `split_segments`.

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
  SVG document. Horizontal dark runs are merged into a single `<path>`;
  colors are validated and `url(...)` is rejected. Invalid colors raise
  `QrError::InvalidColor`.

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
  moonqr - [options] < file
  moonqr [options] -- <payload>

  -l, --level <L|M|Q|H>      error correction level (default M)
  -v, --version <1..40>      force an explicit version
      --min-version <n>      smallest version considered
      --max-version <n>      largest version considered
  -m, --mode <name>          numeric | alphanumeric | byte (default auto)
      --mask <0..7>          force a mask pattern
  -q, -qz, --quiet-zone <n>  quiet zone width in modules (default 4)
  -s, --scale <n>            ASCII scale factor (default 1)
      --module-size <n>      SVG module size in pixels (default 4)
  -f, --format <name>        ascii | half | svg | json (default: by extension)
      --json                 JSON metadata and module rows
  -o, --output <path>        write to a file instead of stdout
      --svg / --half         format shorthands
      --dark / --light       SVG colors
  -h, --help                 show help
  -V, --cli-version          show the CLI version
```

A payload of `-` reads standard input; trailing newlines are stripped. Use
`--` before a payload that starts with a dash. Diagnostics go to stderr, so
stdout stays clean for pipes and files.

Examples:

```bash
moonqr "https://moonbitlang.com" --svg -o site.svg
moonqr "0123456789" -v 2 -m numeric -s 2
moonqr "payload" --min-version 5 --max-version 10 -l Q -f half
echo -n "HELLO" | moonqr - -l H --svg
cat payload.txt | moonqr - -o code.svg
moonqr --json "HELLO" | jq '.version, .size'
moonqr -- --payload-starting-with-dash
```

`--json` (or `-f json`, or a `.json` output path) emits
`{"version":1,"ecLevel":"L","mask":7,"size":21,"modules":["…", …]}` where each
module row is a string of `0`/`1` characters.

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
`encode_bytes_flat_buffer` takes binary data, `encode_bytes_to_modules` returns
the module array directly, and `flat_error_message` renders a readable error.

### Typed ESM/npm wrapper

`npm/` wraps the JS build in a typed ESM API:

```bash
npm ci --prefix npm
npm test --prefix npm   # builds dist/moonbit.js, runs Node + tsc checks
```

```js
import { encode, encodeBytes } from "./npm/index.js";

const qr = encode("HELLO WORLD", { ecLevel: "H", mask: 3 });
const binary = encodeBytes(new Uint8Array([0xff, 0x00]), { ecLevel: "L" });
```

`encode(text, options?)` and `encodeBytes(data, options?)` return
`{ size, version, ecLevel, mask, modules }`; `encodeToBytes` returns the
`Uint8Array` matrix; invalid options throw `QrCodeError`. The package is
marked `private: true` and is not published to the npm registry yet.

Measured artifact sizes (release, this repository):

| Artifact | Raw | gzip |
| --- | --- | --- |
| wasm-gc encoder + flat API (`js.wasm`) | 33.9 KiB | 12.9 KiB |
| JS ESM encoder + flat API (`js.js`) | 100.9 KiB | 14.0 KiB |
| native release CLI (`moonqr.exe`) | 354.2 KiB | — |

## Correctness and testing

```bash
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
moon fmt --check && moon info

# formal capacity contracts (requires z3)
moon prove core/capacity_model

# reference cross-check (Python 3 + qrcode==8.2)
python3 -m pip install -r tools/fuzz/requirements.txt
moon build cmd/moonqr --target native --release
python3 tools/fuzz/verify.py

# CLI smoke tests
python3 tools/cli/smoke.py

# ZXing decode check (Node 18+)
npm ci --prefix tools/zxing
node tools/zxing/verify.js

# npm wrapper tests
npm ci --prefix npm
npm test --prefix npm

# native benchmarks
moon bench benchmarks --target native --release
```

- 88 unit and README tests across `core`, `render`, `content`, `js` and the
  root facade, plus seven native benchmarks.
- Matrix digests are pinned from the Python `qrcode` reference implementation:
  72 byte-mode vectors across versions/EC levels/masks, 32 alphanumeric and
  8 numeric vectors (112 total), plus full-matrix snapshots.
- `tools/fuzz/verify.py` compares 203 forced version/EC/mode/mask matrices
  against Python `qrcode` 8.2 on every run.
- Four capacity contracts (`total_codewords`, `char_count_bits`,
  `numeric_capacity`, `byte_capacity`) are proved with `moon prove` and Z3.
- GF(2<sup>8</sup>), BCH divisibility/known values, RS parity vectors, capacity
  accounting, greedy and optimal segmentation, error paths and SVG/ASCII
  output are covered.
- The same test suite passes on wasm, wasm-gc, JS and native targets, so
  output is bit-identical across the four backends.
- Core coverage is 95.5% (`moon coverage analyze`); remaining uncovered lines
  are defensive invariant checks and unreachable enum arms.
- Twelve generated symbols (all EC levels, UTF-8, forced masks and versions,
  long payloads, payload templates) decode correctly with the ZXing reference
  implementation.
- CI runs the test matrix on Ubuntu and macOS, plus size, ZXing, coverage,
  npm, fuzz, benchmark and formal-proof jobs.

Physical-camera tests on iOS/Android/WeChat are still manual; ZXing decoding,
matrix-level cross-checking and capacity proofs are the automated gates.

## Scope

Implemented: Model 2 versions 1–40, L/M/Q/H, numeric/alphanumeric/byte,
optimal dynamic-programming auto-segmentation, raw bytes and custom segments,
masks, renderers, templates, a stdin/JSON CLI, the flat JS/wasm ABI, a typed
npm wrapper, capacity proofs and reference fuzzing.

Deliberately excluded: decoding, PNG/JPEG/PDF export, logos/styling, Micro QR,
Kanji mode, ECI and Structured Append. Those, plus a published npm package and
physical-camera automation, are candidates for 1.0.

## Project layout

```
core/                 encoder: types, capacity, segments, bit buffer, RS, BCH, matrix, penalty
core/capacity_model/  capacity arithmetic with `moon prove` contracts
benchmarks/           native benchmark suite
render/               ASCII and SVG renderers
content/              payload templates
js/                   flat Uint8Array ABI + ESM/wasm-gc link exports
npm/                  typed ESM wrapper (private) + Node/TypeScript tests
cmd/moonqr            CLI
tools/zxing           ZXing decode verification harness (Node)
tools/fuzz            Python qrcode matrix cross-check
tools/cli             CLI smoke tests
```

`core`, `core/capacity_model`, `render`, `content` and `js` use only the
MoonBit standard library. The CLI adds `moonbitlang/x` for filesystem and
process support.

## License

Apache-2.0.
