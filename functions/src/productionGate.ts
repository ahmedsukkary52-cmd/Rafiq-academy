import { getApps } from "firebase-admin/app";
import { HttpsError } from "firebase-functions/v2/https";
import { emulatorProjectProblem, isFunctionsEmulator } from "./emulatorProjectGuard";

/**
 * WA-0 / C12 — Production backend activation gate.
 *
 * B-BILLING is unresolved until FIREBASE_BILLING_CHECKLIST.md Verified columns
 * and Pre-Blaze gate are completed. Do not invent pricing or enable Blaze here.
 *
 * Allowed backends:
 * - Firebase Emulator only when FUNCTIONS_EMULATOR === "true"
 *   (set automatically by the Functions emulator — not a free-form env knob)
 *   AND every resolved project ID is a demo-* project (emulatorProjectGuard)
 * - Explicit PRODUCTION_BACKEND_ENABLED === "true" after B-BILLING Verified
 *
 * Intentionally does NOT honor ALLOW_EMULATOR_BACKEND — that env could be
 * accidentally set on a deployed Cloud Function and bypass the billing gate.
 */

export function isProductionBackendEnabled(): boolean {
  return process.env.PRODUCTION_BACKEND_ENABLED === "true";
}

export function isEmulatorBackendAllowed(): boolean {
  // Firebase sets FUNCTIONS_EMULATOR only inside the Functions emulator
  // process; a real project ID there would route calls to real services.
  if (!isFunctionsEmulator()) return false;
  const appProjectId = getApps()[0]?.options.projectId;
  return emulatorProjectProblem(process.env, appProjectId) === null;
}

/**
 * Callables that are safe to exercise in the emulator may proceed when
 * FUNCTIONS_EMULATOR is set. Production invocation requires an explicit
 * PRODUCTION_BACKEND_ENABLED=true after B-BILLING is Verified.
 */
export function assertBackendAllowed(feature: string): void {
  if (isProductionBackendEnabled() || isEmulatorBackendAllowed()) {
    return;
  }
  throw new HttpsError(
    "failed-precondition",
    `Backend feature "${feature}" is disabled until B-BILLING is Verified ` +
      `(see docs/production/FIREBASE_BILLING_CHECKLIST.md). ` +
      `Use the Firebase Functions Emulator (FUNCTIONS_EMULATOR) for local ` +
      `verification, or set PRODUCTION_BACKEND_ENABLED=true only after billing ` +
      `verification.`,
  );
}
