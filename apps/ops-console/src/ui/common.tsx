import { MS1_RESERVE_BANNER } from "@rwa-vault/types";
import type { ReactNode } from "react";

/** The ADR 0017 banner. It has no close control: it cannot be dismissed (AC-12). */
export function ReserveBanner() {
  return (
    <div role="alert" className="banner" data-testid="ms1-banner">
      {MS1_RESERVE_BANNER}
    </div>
  );
}

export function Problem({ children }: { children: ReactNode }) {
  return (
    <p role="status" className="problem">
      {children}
    </p>
  );
}

export function Check({ ok, children }: { ok: boolean; children: ReactNode }) {
  return (
    <li className={ok ? "ok" : "fail"}>
      <span aria-hidden="true">{ok ? "✅" : "❌"}</span> {children}
    </li>
  );
}

/** Formats an 18-decimal fine-gram amount for people; the exact integer is shown beside it. */
export function grams(wei: bigint): string {
  const whole = wei / 10n ** 18n;
  const frac = (wei % 10n ** 18n).toString().padStart(18, "0").slice(0, 4).replace(/0+$/, "");
  return `${whole}${frac ? `.${frac}` : ""} g`;
}
