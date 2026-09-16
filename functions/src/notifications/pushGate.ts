import {
  isEmulatorBackendAllowed,
  isProductionBackendEnabled,
} from "../productionGate";

/**
 * WA-13 / C11 + WA-0 / C12 — push send gate.
 *
 * Reuses the existing production gate predicates unchanged: real FCM sending
 * is only reachable inside the Functions emulator, or in production after
 * B-BILLING is Verified and PRODUCTION_BACKEND_ENABLED=true.
 *
 * Background triggers must not throw on a closed gate (a throw becomes an
 * infinite retry loop), so the trigger logs and returns — same shape as the
 * scheduled WA-6 job in billing/processOverdueGrace.ts.
 */
export type PushSendMode = "production" | "emulator" | "blocked";

export function resolvePushSendMode(): PushSendMode {
  if (isProductionBackendEnabled()) return "production";
  if (isEmulatorBackendAllowed()) return "emulator";
  return "blocked";
}

export function isPushSendAllowed(mode: PushSendMode): boolean {
  return mode !== "blocked";
}

export function pushGateBlockedMessage(feature: string): string {
  return (
    `[WA-13] ${feature} skipped — B-BILLING gate closed ` +
    `(see docs/production/FIREBASE_BILLING_CHECKLIST.md). Set ` +
    `FUNCTIONS_EMULATOR for local verification, or ` +
    `PRODUCTION_BACKEND_ENABLED=true only after billing verification.`
  );
}
