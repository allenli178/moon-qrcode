import {
  encode,
  encodeBytes,
  encodeToBytes,
  QrCodeError,
  type EcLevel,
  type EncodedQr,
} from "../index.js";

const qr: EncodedQr = encode("HELLO", {
  ecLevel: "Q",
  minVersion: 1,
  maxVersion: 10,
  mask: 3,
});
const level: EcLevel = qr.ecLevel;
const bytes: Uint8Array = encodeToBytes("hi");
const fromBytes: EncodedQr = encodeBytes(new Uint8Array([0xff, 0x00]), {
  ecLevel: 0,
  mask: 7,
});

if (level === "Q" && bytes.length !== qr.size * qr.size) {
  throw new QrCodeError("unexpected matrix size");
}
if (fromBytes.mask !== 7 || fromBytes.ecLevel !== "L") {
  throw new QrCodeError("unexpected byte-encoding metadata");
}

// @ts-expect-error unknown EC level
encode("hi", { ecLevel: "Z" });
// @ts-expect-error mask must be 0..7
encode("hi", { mask: 8 });
// @ts-expect-error text payloads must be strings
encode(42);
// @ts-expect-error byte payloads must be Uint8Array
encodeBytes("hi");
