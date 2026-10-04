/**
 * Typed adapter and loader over the WASM package (`pkg/`).
 *
 * Implements the same {@link PqCoreApi} interface as the native adapter.
 * The WASM module is loaded lazily on `init()`.
 */

import type {
  PqCoreApi,
  PqEncapsulation,
  PqKemAlgorithm,
  PqKemMetadata,
  PqKeyPair,
  PqSignatureAlgorithm,
  PqSignatureMetadata,
} from "./types.js";
import { pqErrorFromCode } from "./errors.js";
import { SIGNATURE_METADATA, KEM_METADATA } from "./metadata.js";

interface WasmKeyPairLike {
  readonly publicKey: Uint8Array;
  readonly privateKey: Uint8Array;
  free(): void;
}

interface WasmEncapsulationLike {
  readonly ciphertext: Uint8Array;
  readonly sharedSecret: Uint8Array;
  free(): void;
}

interface WasmModule {
  default: (input?: RequestInfo | URL | BufferSource) => Promise<void>;
  init(): void;
  keygen(algorithm: string): WasmKeyPairLike;
  sign(algorithm: string, privateKey: Uint8Array, message: Uint8Array): Uint8Array;
  verify(
    algorithm: string,
    publicKey: Uint8Array,
    message: Uint8Array,
    signature: Uint8Array,
  ): boolean;
  signatureMetadata(algorithm: string): Record<string, unknown>;
  kemKeygen(algorithm: string): WasmKeyPairLike;
  encapsulate(algorithm: string, publicKey: Uint8Array): WasmEncapsulationLike;
  decapsulate(
    algorithm: string,
    privateKey: Uint8Array,
    ciphertext: Uint8Array,
  ): Uint8Array;
  kemMetadata(algorithm: string): Record<string, unknown>;
}

let wasm: WasmModule | undefined;

function getWasm(): WasmModule {
  if (!wasm) {
    throw pqErrorFromCode("NOT_INITIALISED");
  }
  return wasm;
}

function wrapWasmError(error: unknown): never {
  if (error instanceof Error) {
    const code = (error as Error & { code?: unknown }).code;
    if (typeof code === "string") {
      throw pqErrorFromCode(code, error.message);
    }
    throw pqErrorFromCode("INTERNAL_ERROR", error.message);
  }
  throw pqErrorFromCode("INTERNAL_ERROR", String(error));
}

export function createWasmAdapter(): PqCoreApi {
  return {
    async init(): Promise<void> {
      const mod = await import("../pkg/rwa_vault_pq_core.js") as unknown as WasmModule;
      await mod.default();
      mod.init();
      wasm = mod;
    },

    async keygen(algorithm: PqSignatureAlgorithm): Promise<PqKeyPair> {
      try {
        const pair = getWasm().keygen(algorithm);
        const result: PqKeyPair = {
          publicKey: new Uint8Array(pair.publicKey),
          privateKey: new Uint8Array(pair.privateKey),
        };
        pair.free();
        return result;
      } catch (error) {
        wrapWasmError(error);
      }
    },

    async sign(
      algorithm: PqSignatureAlgorithm,
      privateKey: Uint8Array,
      message: Uint8Array,
    ): Promise<Uint8Array> {
      try {
        return getWasm().sign(algorithm, privateKey, message);
      } catch (error) {
        wrapWasmError(error);
      }
    },

    async verify(
      algorithm: PqSignatureAlgorithm,
      publicKey: Uint8Array,
      message: Uint8Array,
      signature: Uint8Array,
    ): Promise<boolean> {
      try {
        return getWasm().verify(algorithm, publicKey, message, signature);
      } catch (error) {
        wrapWasmError(error);
      }
    },

    metadata(algorithm: PqSignatureAlgorithm): PqSignatureMetadata {
      return SIGNATURE_METADATA[algorithm];
    },

    async kemKeygen(algorithm: PqKemAlgorithm): Promise<PqKeyPair> {
      try {
        const pair = getWasm().kemKeygen(algorithm);
        const result: PqKeyPair = {
          publicKey: new Uint8Array(pair.publicKey),
          privateKey: new Uint8Array(pair.privateKey),
        };
        pair.free();
        return result;
      } catch (error) {
        wrapWasmError(error);
      }
    },

    async encapsulate(
      algorithm: PqKemAlgorithm,
      publicKey: Uint8Array,
    ): Promise<PqEncapsulation> {
      try {
        const enc = getWasm().encapsulate(algorithm, publicKey);
        const result: PqEncapsulation = {
          ciphertext: new Uint8Array(enc.ciphertext),
          sharedSecret: new Uint8Array(enc.sharedSecret),
        };
        enc.free();
        return result;
      } catch (error) {
        wrapWasmError(error);
      }
    },

    async decapsulate(
      algorithm: PqKemAlgorithm,
      privateKey: Uint8Array,
      ciphertext: Uint8Array,
    ): Promise<Uint8Array> {
      try {
        return getWasm().decapsulate(algorithm, privateKey, ciphertext);
      } catch (error) {
        wrapWasmError(error);
      }
    },

    kemMetadata(algorithm: PqKemAlgorithm): PqKemMetadata {
      return KEM_METADATA[algorithm];
    },
  };
}
