import assert from "node:assert/strict";
import test from "node:test";

import { encode, encodeBytes, encodeToBytes, QrCodeError } from "../index.js";

test("encodes with defaults", () => {
  const qr = encode("HELLO WORLD");
  assert.equal(qr.version, 1);
  assert.equal(qr.size, 21);
  assert.equal(qr.ecLevel, "M");
  assert.ok(qr.mask >= 0 && qr.mask <= 7);
  assert.ok(qr.modules instanceof Uint8Array);
  assert.equal(qr.modules.length, 21 * 21);
  assert.equal(qr.modules[0], 1);
});

test("honors version, EC level and mask options", () => {
  const qr = encode("HELLO WORLD", {
    ecLevel: "H",
    minVersion: 10,
    maxVersion: 10,
    mask: 3,
  });
  assert.equal(qr.version, 10);
  assert.equal(qr.size, 57);
  assert.equal(qr.ecLevel, "H");
  assert.equal(qr.mask, 3);
});

test("accepts numeric EC indexes", () => {
  const named = encode("HELLO", { ecLevel: "Q", mask: 0 });
  const indexed = encode("HELLO", { ecLevel: 2, mask: 0 });
  assert.equal(indexed.ecLevel, "Q");
  assert.deepEqual(indexed.modules, named.modules);
});

test("encodes UTF-8 payloads", () => {
  const qr = encode("你好，世界", { ecLevel: "Q" });
  assert.equal(qr.size, qr.version * 4 + 17);
  assert.equal(qr.modules.length, qr.size * qr.size);
});

test("produces deterministic matrices", () => {
  const first = encode("deterministic payload", { mask: 5 });
  const second = encode("deterministic payload", { mask: 5 });
  assert.deepEqual(first.modules, second.modules);
  assert.equal(first.mask, second.mask);
});

test("encodeToBytes returns the row-major matrix", () => {
  const bytes = encodeToBytes("hi", { ecLevel: "L" });
  assert.ok(bytes instanceof Uint8Array);
  assert.equal(bytes.length, 21 * 21);
  for (const value of bytes) {
    assert.ok(value === 0 || value === 1);
  }
});

test("encodeBytes preserves arbitrary binary payloads", () => {
  const data = new Uint8Array([0xff, 0x00, 0x80, 0x41]);
  const qr = encodeBytes(data, { ecLevel: "L", mask: 2 });
  assert.equal(qr.version, 1);
  assert.equal(qr.size, 21);
  assert.equal(qr.ecLevel, "L");
  assert.equal(qr.mask, 2);
  assert.equal(qr.modules.length, 21 * 21);
  const again = encodeBytes(data, { ecLevel: "L", mask: 2 });
  assert.deepEqual(again.modules, qr.modules);
});

test("encodeBytes honours min/max version and mask", () => {
  const qr = encodeBytes(new Uint8Array([1, 2, 3]), {
    minVersion: 6,
    maxVersion: 6,
    mask: 7,
  });
  assert.equal(qr.version, 6);
  assert.equal(qr.size, 41);
  assert.equal(qr.mask, 7);
});

test("reports encoder errors as QrCodeError", () => {
  assert.throws(
    () => encode(""),
    (error) =>
      error instanceof QrCodeError && error.message === "input is empty",
  );
  assert.throws(
    () =>
      encode("x".repeat(5000), {
        ecLevel: "L",
        minVersion: 1,
        maxVersion: 1,
      }),
    (error) =>
      error instanceof QrCodeError && error.message.includes("bits but V1"),
  );
  assert.throws(
    () => encode("hi", { minVersion: 0 }),
    (error) =>
      error instanceof QrCodeError &&
      error.message.includes("invalid QR version 0"),
  );
  assert.throws(
    () => encodeBytes(new Uint8Array()),
    (error) =>
      error instanceof QrCodeError && error.message === "input is empty",
  );
});

test("rejects invalid option and input types before encoding", () => {
  assert.throws(() => encode(42), TypeError);
  assert.throws(() => encodeBytes("hi"), TypeError);
  assert.throws(() => encodeBytes([1, 2, 3]), TypeError);
  assert.throws(() => encode("hi", { ecLevel: "Z" }), TypeError);
  assert.throws(() => encode("hi", { ecLevel: 4 }), TypeError);
  assert.throws(() => encode("hi", { mask: 8 }), TypeError);
  assert.throws(() => encode("hi", { mask: 1.5 }), TypeError);
  assert.throws(() => encode("hi", { minVersion: "1" }), TypeError);
  assert.throws(() => encode("hi", null), TypeError);
});
