/**
 * M8 Mock settlement rail.
 *
 * This is the ONLY simulated leg of the protocol. It sits behind one interface so that
 * replacing it with a licensed provider is a configuration change plus that provider's
 * integration tests, not a redesign. Everything downstream of the USDC credit - the
 * cryptography, contracts, accounting, risk engine and tests - is the production article.
 */

export interface IFiatRail {
  /** Credit test-net USDC against a simulated PKR debit. Double-entry, always balanced. */
  onRamp(accountId: string, pkrAmount: bigint): Promise<{ ledgerEntryId: string }>;
  /** The mirror leg. */
  offRamp(accountId: string, usdcAmount: bigint): Promise<{ ledgerEntryId: string }>;
}
