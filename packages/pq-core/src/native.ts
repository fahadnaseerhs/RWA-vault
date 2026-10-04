/**
 * Typed adapter over the napi-rs Node addon.
 *
 * Implements the shared {@link PqCoreApi} contract. Every operation is async
 * (the addon runs cryptographic work on the libuv thread pool via AsyncTask).
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

interface NapiAddon {
  keygen(algorithm: string): Promise<{ publicKey: Buffer; privateKey: Buffer }>;
  sign(algorithm: string, privateKey: Buffer, message: Buffer): Promise<Buffer>;
  verify(
    algorithm: string,
    publicKey: Buffer,
    message: Buffer,
    signature: Buffer,
  ): Promise<boolean>;
  signatureMetadata(algorithm: string): {
    algorithm: string;
    publicKeyBytes: number;
    privateKeyBytes: number;
    signatureBytes: number;
  };
  kemKeygen(algorithm: string): Promise<{ publicKey: Buffer; privateKey: Buffer }>;
  encapsulate(
    algorithm: string,
    publicKey: Buffer,
  ): Promise<{ ciphertext: Buffer; sharedSecret: Buffer }>;
  decapsulate(algorithm: string, privateKey: Buffer, ciphertext: Buffer): Promise<Buffer>;
  kemMetadata(algorithm: string): {
    algorithm: string;
    publicKeyBytes: number;
    privateKeyBytes: number;
    ciphertextBytes: number;
    sharedSecretBytes: number;
  };
}

let addon: NapiAddon | undefined;

function getAddon(): NapiAddon {
  if (!addon) {
    throw pqErrorFromCode("NOT_INITIALISED");
  }
  return addon;
}

function wrapNapiError(error: unknown): never {
  if (error instanceof Error) {
    const match = /^\[([A-Z_]+)\] (.*)$/.exec(error.message);
    if (match) {
      throw pqErrorFromCode(match[1], match[2]);
    }
  }
  throw pqErrorFromCode("INTERNAL_ERROR", String(error));
}

function toUint8Array(buffer: Buffer | Uint8Array): Uint8Array {
  if (buffer instanceof Uint8Array) return buffer;
  return new Uint8Array(buffer);
}

export function createNativeAdapter(): PqCoreApi {
  return {
    async init(): Promise<void> {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      addon = require("../pq-core.node") as NapiAddon;
    },

    async keygen(algorithm: PqSignatureAlgorithm): Promise<PqKeyPair> {
      try {
        const result = await getAddon().keygen(algorithm);
        return {
          publicKey: toUint8Array(result.publicKey),
          privateKey: toUint8Array(result.privateKey),
        };
      } catch (error) {
        wrapNapiError(error);
      }
    },

    async sign(
      algorithm: PqSignatureAlgorithm,
      privateKey: Uint8Array,
      message: Uint8Array,
    ): Promise<Uint8Array> {
      try {
        const result = await getAddon().sign(
          algorithm,
          Buffer.from(privateKey),
          Buffer.from(message),
        );
        return toUint8Array(result);
      } catch (error) {
        wrapNapiError(error);
      }
    },

    async verify(
      algorithm: PqSignatureAlgorithm,
      publicKey: Uint8Array,
      message: Uint8Array,
      signature: Uint8Array,
    ): Promise<boolean> {
      try {
        return await getAddon().verify(
          algorithm,
          Buffer.from(publicKey),
          Buffer.from(message),
          Buffer.from(signature),
        );
      } catch (error) {
        wrapNapiError(error);
      }
    },

    metadata(algorithm: PqSignatureAlgorithm): PqSignatureMetadata {
      return SIGNATURE_METADATA[algorithm];
    },

    async kemKeygen(algorithm: PqKemAlgorithm): Promise<PqKeyPair> {
      try {
        const result = await getAddon().kemKeygen(algorithm);
        return {
          publicKey: toUint8Array(result.publicKey),
          privateKey: toUint8Array(result.privateKey),
        };
      } catch (error) {
        wrapNapiError(error);
      }
    },

    async encapsulate(
      algorithm: PqKemAlgorithm,
      publicKey: Uint8Array,
    ): Promise<PqEncapsulation> {
      try {
        const result = await getAddon().encapsulate(algorithm, Buffer.from(publicKey));
        return {
          ciphertext: toUint8Array(result.ciphertext),
          sharedSecret: toUint8Array(result.sharedSecret),
        };
      } catch (error) {
        wrapNapiError(error);
      }
    },

    async decapsulate(
      algorithm: PqKemAlgorithm,
      privateKey: Uint8Array,
      ciphertext: Uint8Array,
    ): Promise<Uint8Array> {
      try {
        const result = await getAddon().decapsulate(
          algorithm,
          Buffer.from(privateKey),
          Buffer.from(ciphertext),
        );
        return toUint8Array(result);
      } catch (error) {
        wrapNapiError(error);
      }
    },

    kemMetadata(algorithm: PqKemAlgorithm): PqKemMetadata {
      return KEM_METADATA[algorithm];
    },
  };
}
