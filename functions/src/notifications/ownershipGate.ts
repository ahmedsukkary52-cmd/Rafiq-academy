import {
  isEmulatorBackendAllowed,
  isProductionBackendEnabled,
} from "../productionGate";

/**
 * H2 — FCM token ownership reconciliation gate, separate from the push gate.
 *
 * Reconciling `fcmTokenOwners` only writes server-owned Firestore records and
 * never sends. Allowing it while pushGate stays closed keeps ownership current
 * for every registration, so enabling sending later does not inherit tokens
 * registered in the meantime as unowned (legacy-permissive).
 *
 * Opens only on FCM_OWNERSHIP_ENABLED === "true" (explicit opt-in, no
 * default), and wherever the shared backend gate is open, so the sender's
 * ownership filter never runs ahead of reconciliation. pushGate never reads
 * this flag: opening it cannot enable any push.
 */
export const OWNERSHIP_GATE_ENV = "FCM_OWNERSHIP_ENABLED";

export function isOwnershipReconcileEnabled(): boolean {
  return (
    process.env[OWNERSHIP_GATE_ENV] === "true" ||
    isProductionBackendEnabled() ||
    isEmulatorBackendAllowed()
  );
}
