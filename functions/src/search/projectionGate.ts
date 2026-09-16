import {
  isEmulatorBackendAllowed,
  isProductionBackendEnabled,
} from "../productionGate";

/**
 * WA-14 / C13 + WA-0 / C12 — background materializer gate.
 *
 * Reuses the existing production gate predicates unchanged. Background
 * triggers must not throw on a closed gate (a throw becomes an infinite retry
 * loop), so they log and return — the same non-throwing shape WA-13 uses for
 * the evaluation push chain. The Admin backfill callable keeps the throwing
 * `assertBackendAllowed`, because a callable can surface the error.
 */
export type ProjectionRunMode = "production" | "emulator" | "blocked";

export function resolveProjectionRunMode(): ProjectionRunMode {
  if (isProductionBackendEnabled()) return "production";
  if (isEmulatorBackendAllowed()) return "emulator";
  return "blocked";
}

export function isProjectionRunAllowed(mode: ProjectionRunMode): boolean {
  return mode !== "blocked";
}

export function projectionGateBlockedMessage(feature: string): string {
  return (
    `[WA-14] ${feature} skipped — B-BILLING gate closed ` +
    `(see docs/production/FIREBASE_BILLING_CHECKLIST.md). Set ` +
    `FUNCTIONS_EMULATOR for local verification, or ` +
    `PRODUCTION_BACKEND_ENABLED=true only after billing verification.`
  );
}
