export type EcLevel = "L" | "M" | "Q" | "H";

export type MaskPattern = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7;

export interface EncodeOptions {
  /** Error-correction level; defaults to "M". */
  ecLevel?: EcLevel | 0 | 1 | 2 | 3;
  /** Smallest version considered; defaults to 1. */
  minVersion?: number;
  /** Largest version considered; defaults to 40. */
  maxVersion?: number;
  /** Force a mask pattern instead of using the lowest-penalty one. */
  mask?: MaskPattern;
}

export interface EncodedQr {
  /** Side length in modules (4 * version + 17). */
  readonly size: number;
  /** QR version 1..40. */
  readonly version: number;
  readonly ecLevel: EcLevel;
  readonly mask: MaskPattern;
  /** Row-major modules, one byte per module (1 = dark, 0 = light). */
  readonly modules: Uint8Array;
}

export declare class QrCodeError extends Error {
  constructor(message: string, cause?: unknown);
}

export declare function encode(text: string, options?: EncodeOptions): EncodedQr;

export declare function encodeBytes(
  data: Uint8Array,
  options?: EncodeOptions,
): EncodedQr;

export declare function encodeToBytes(
  text: string,
  options?: EncodeOptions,
): Uint8Array;
