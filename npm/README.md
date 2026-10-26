# @allenli178/moon-qrcode

ESM wrapper around the pure-MoonBit QR Code Model 2 encoder.

```bash
npm run build
```

```js
import { encode, encodeBytes } from "@allenli178/moon-qrcode";

const qr = encode("HELLO WORLD", { ecLevel: "M" });
console.log(qr.version, qr.size, qr.ecLevel, qr.mask);

// Row-major modules, 1 = dark, 0 = light.
for (let row = 0; row < qr.size; row++) {
  let line = "";
  for (let col = 0; col < qr.size; col++) {
    line += qr.modules[row * qr.size + col] ? "██" : "  ";
  }
  console.log(line);
}

// Binary payloads are passed through byte-for-byte.
const binary = encodeBytes(new Uint8Array([0xff, 0x00, 0x80]), {
  ecLevel: "L",
});
```

`encodeToBytes` returns the same matrix without the metadata.

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `ecLevel` | `"M"` | `"L"`, `"M"`, `"Q"`, `"H"` (or `0..3`) |
| `minVersion` / `maxVersion` | `1` / `40` | Version search range |
| `mask` | auto | Force a mask pattern `0..7` |

`encode` accepts a string and selects numeric, alphanumeric and byte segments
optimally. `encodeBytes` encodes a `Uint8Array` as one Byte segment, preserving
arbitrary binary data.

Errors are thrown as `QrCodeError` with the encoder's diagnostic message.

This package is marked `private` and is not published. Run `npm run pack:check`
to validate the tarball contents, or `npm test` to run the Node and TypeScript
checks.
