/**
 * M10 Provider and operations consoles.
 *
 * Provider: submit asset metadata, valuation basis and custodian; drive the attestation
 * flow. Operations: monitor health-factor bands, buffer utilisation and liquidations.
 * Neither console can move funds - no off-chain component in this system can.
 */

export const CONSOLE_NAME = "RWA-Vault Operations";
