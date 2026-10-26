import {
  encode_to_modules,
  encode_bytes_to_modules,
  flat_error_message,
} from "./dist/moonbit.js";

const EC_LEVELS = ["L", "M", "Q", "H"];
const EC_INDEX = { L: 0, M: 1, Q: 2, H: 3 };

export class QrCodeError extends Error {
  constructor(message, cause) {
    super(message, { cause });
    this.name = "QrCodeError";
  }
}

function unwrap(result) {
  if (result.$tag === 1) {
    return result._0;
  }
  throw new QrCodeError(flat_error_message(result._0), result._0);
}

function normalizeOptions(options = {}) {
  if (options === null || typeof options !== "object") {
    throw new TypeError("options must be an object");
  }
  const requested = options.ecLevel ?? "M";
  let ecIndex;
  if (typeof requested === "string") {
    ecIndex = EC_INDEX[requested.toUpperCase()];
  } else if (Number.isInteger(requested) && requested >= 0 && requested <= 3) {
    ecIndex = requested;
  }
  if (ecIndex === undefined) {
    throw new TypeError(`invalid ecLevel: ${String(requested)}`);
  }
  const minVersion = options.minVersion ?? 1;
  const maxVersion = options.maxVersion ?? 40;
  if (!Number.isInteger(minVersion) || !Number.isInteger(maxVersion)) {
    throw new TypeError("minVersion and maxVersion must be integers");
  }
  const mask = options.mask;
  if (
    mask !== undefined &&
    (!Number.isInteger(mask) || mask < 0 || mask > 7)
  ) {
    throw new TypeError("mask must be an integer between 0 and 7");
  }
  return { ecIndex, minVersion, maxVersion, mask };
}

function toEncodedQr(flat) {
  return Object.freeze({
    size: flat.size_,
    version: flat.version_,
    ecLevel: EC_LEVELS[flat.ec_level_],
    mask: flat.mask_,
    modules: flat.data_,
  });
}

function encodeWith(encoder, input, options) {
  const { ecIndex, minVersion, maxVersion, mask } = normalizeOptions(options);
  return toEncodedQr(
    unwrap(encoder(input, ecIndex, minVersion, maxVersion, mask)),
  );
}

export function encode(text, options) {
  if (typeof text !== "string") {
    throw new TypeError("text must be a string");
  }
  return encodeWith(encode_to_modules, text, options);
}

export function encodeBytes(data, options) {
  if (!(data instanceof Uint8Array)) {
    throw new TypeError("data must be a Uint8Array");
  }
  return encodeWith(encode_bytes_to_modules, data, options);
}

export function encodeToBytes(text, options) {
  return encode(text, options).modules;
}
