#!/usr/bin/env node
// Decodes MoonQR output with the ZXing reference implementation.
//
//   moon build cmd/moonqr --target native --release
//   npm ci --prefix tools/zxing
//   node tools/zxing/verify.js
//
// Set MOONQR_CLI to use a different moonqr binary.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const {
  BinaryBitmap,
  BarcodeFormat,
  DecodeHintType,
  HybridBinarizer,
  LuminanceSource,
  MultiFormatReader,
  ResultMetadataType,
} = require("@zxing/library");

const root = path.resolve(__dirname, "..", "..");
const cliCandidates = [
  process.env.MOONQR_CLI,
  path.join(root, "_build/native/release/build/cmd/moonqr/moonqr.exe"),
  path.join(root, "_build/native/release/build/cmd/moonqr/moonqr"),
  path.join(root, "_build/native/debug/build/cmd/moonqr/moonqr.exe"),
].filter(Boolean);
const cli = cliCandidates.find((candidate) => fs.existsSync(candidate));
if (!cli) {
  console.error(
    "moonqr binary not found. Build it first:\n" +
      "  moon build cmd/moonqr --target native --release",
  );
  process.exit(2);
}

class GraySource extends LuminanceSource {
  constructor(pixels, width, height) {
    super(width, height);
    this.pixels = pixels;
  }

  getRow(y, row) {
    const w = this.getWidth();
    const out = row && row.length >= w ? row : new Uint8ClampedArray(w);
    out.set(this.pixels.subarray(y * w, (y + 1) * w));
    return out;
  }

  getMatrix() {
    return this.pixels;
  }

  isCropSupported() {
    return false;
  }

  isRotateSupported() {
    return false;
  }
}

function svgToLuminance(svg, scale) {
  const viewBox = svg.match(/viewBox="0 0 (\d+) (\d+)"/);
  if (!viewBox) throw new Error("viewBox not found in SVG");
  const modules = Number(viewBox[1]);
  const pixels = modules * scale;
  const luminances = new Uint8ClampedArray(pixels * pixels).fill(255);
  const darkRect = /<rect x="(\d+)" y="(\d+)" width="1" height="1"\/>/g;
  let dark = 0;
  let rect;
  while ((rect = darkRect.exec(svg)) !== null) {
    const x = Number(rect[1]);
    const y = Number(rect[2]);
    dark++;
    for (let dy = 0; dy < scale; dy++) {
      const start = (y * scale + dy) * pixels + x * scale;
      luminances.fill(0, start, start + scale);
    }
  }
  if (dark === 0) throw new Error("SVG contains no dark modules");
  return { luminances, width: pixels, height: pixels };
}

const cases = [
  {
    name: "numeric v1-L",
    text: "01234567",
    ec: "L",
    opts: ["-l", "L", "-m", "numeric"],
  },
  {
    name: "alphanumeric H",
    text: "HELLO WORLD",
    ec: "H",
    opts: ["-l", "H"],
  },
  {
    name: "url M",
    text: "https://moonbitlang.com",
    ec: "M",
    opts: ["-l", "M"],
  },
  {
    name: "utf8 chinese Q",
    text: "你好，MoonBit QR 二维码",
    ec: "Q",
    opts: ["-l", "Q"],
  },
  {
    name: "wifi template",
    text: "WIFI:T:WPA;S:Cafe;P:latte;;",
    ec: "M",
    opts: [],
  },
  {
    name: "forced mask 0",
    text: "HELLO WORLD",
    ec: "L",
    opts: ["-l", "L", "--mask", "0"],
  },
  {
    name: "forced mask 7",
    text: "HELLO WORLD",
    ec: "L",
    opts: ["-l", "L", "--mask", "7"],
  },
  {
    name: "long alphanumeric L",
    text: "A".repeat(200),
    ec: "L",
    opts: ["-l", "L"],
  },
  {
    name: "long byte Q",
    text: "x".repeat(500),
    ec: "Q",
    opts: ["-l", "Q"],
  },
  {
    name: "forced version 10 H",
    text: "https://example.com/path?q=1&x=2",
    ec: "H",
    opts: ["-l", "H", "-v", "10"],
  },
  {
    name: "long numeric H",
    text: "1234567890".repeat(30),
    ec: "H",
    opts: ["-l", "H"],
  },
  {
    name: "mailto",
    text: "mailto:ada@example.com?subject=Hi%20there&body=Hello",
    ec: "M",
    opts: [],
  },
];

const reader = new MultiFormatReader();
const hints = new Map();
hints.set(DecodeHintType.POSSIBLE_FORMATS, [BarcodeFormat.QR_CODE]);
hints.set(DecodeHintType.TRY_HARDER, true);

let passed = 0;
for (const testCase of cases) {
  const run = spawnSync(
    cli,
    [testCase.text, "-f", "svg", "-qz", "4", ...testCase.opts],
    { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
  );
  if (run.status !== 0) {
    console.log(`FAIL ${testCase.name}: moonqr exited ${run.status}`);
    if (run.stderr) console.log(`  ${run.stderr.trim()}`);
    continue;
  }

  try {
    const { luminances, width, height } = svgToLuminance(run.stdout, 8);
    const source = new GraySource(luminances, width, height);
    const result = reader.decode(
      new BinaryBitmap(new HybridBinarizer(source)),
      hints,
    );
    const decoded = result.getText();
    if (decoded !== testCase.text) {
      console.log(`FAIL ${testCase.name}: decoded text differs from input`);
      continue;
    }
    const metadata = result.getResultMetadata();
    const actualEc =
      metadata && metadata.get(ResultMetadataType.ERROR_CORRECTION_LEVEL);
    if (actualEc && actualEc !== testCase.ec) {
      console.log(
        `FAIL ${testCase.name}: ec ${actualEc} != expected ${testCase.ec}`,
      );
      continue;
    }
    passed++;
    console.log(`PASS ${testCase.name} (ec=${actualEc || testCase.ec})`);
  } catch (error) {
    console.log(`FAIL ${testCase.name}: ${error.name}: ${error.message}`);
  }
}

console.log(`\n${passed}/${cases.length} decoded by ZXing`);
process.exit(passed === cases.length ? 0 : 1);
