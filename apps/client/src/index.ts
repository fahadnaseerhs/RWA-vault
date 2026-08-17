/**
 * M10 Investor PWA.
 *
 * The Falcon-512 device key is generated on the device, stored in IndexedDB and never
 * transmitted. Signing runs in Rust compiled to WASM. Falcon is verified everywhere but
 * signed only here: its Gaussian sampling is a side-channel hazard a browser tab holding
 * one user's key can carry and a shared service host holding protocol keys cannot.
 */

export const APP_NAME = "RWA-Vault";
