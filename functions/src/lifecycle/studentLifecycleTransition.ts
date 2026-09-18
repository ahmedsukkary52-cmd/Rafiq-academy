/**
 * WA-15 / C14.3 — pure lifecycle transition logic.
 *
 * No Firebase imports: the callable stays a thin IO shell and every rule below
 * is unit-testable without an emulator.
 */

import {
  LIFECYCLE_TARGET,
  LifecycleAction,
  LifecycleValue,
  normalizeLifecycle,
} from "./studentLifecycleContract";

/** Why a transition cannot proceed. Maps 1:1 to a callable error code. */
export type LifecycleRejection =
  | "student_not_found"
  | "not_a_student"
  | "profile_not_found";

export type LifecycleSubject = {
  /** `users/{uid}` — null when the document does not exist. */
  user: { role?: unknown } | null;
  /** `studentProfiles/{uid}` — null when the document does not exist. */
  profile: { lifecycle?: unknown } | null;
};

export type LifecycleDecision =
  | { outcome: "rejected"; reason: LifecycleRejection }
  | {
      /** Already in the target state — succeed without writing or auditing. */
      outcome: "noop";
      current: LifecycleValue;
    }
  | {
      outcome: "transition";
      from: LifecycleValue;
      to: LifecycleValue;
    };

/**
 * Validates the subject and resolves the transition.
 *
 * Idempotency contract: re-issuing an action that is already satisfied is a
 * SUCCESS with `outcome: "noop"`. It writes nothing and emits no audit entry,
 * so a retried or double-clicked archive cannot produce duplicate log noise.
 * Only `active ⇄ archived` transitions are ever written.
 */
export function decideLifecycleTransition(params: {
  action: LifecycleAction;
  subject: LifecycleSubject;
}): LifecycleDecision {
  const { action, subject } = params;

  if (subject.user === null) {
    return { outcome: "rejected", reason: "student_not_found" };
  }
  const role = typeof subject.user.role === "string"
    ? subject.user.role.trim()
    : "";
  if (role !== "student") {
    return { outcome: "rejected", reason: "not_a_student" };
  }
  if (subject.profile === null) {
    return { outcome: "rejected", reason: "profile_not_found" };
  }

  const current = normalizeLifecycle(subject.profile.lifecycle);
  const target = LIFECYCLE_TARGET[action];

  if (current === target) return { outcome: "noop", current };

  return { outcome: "transition", from: current, to: target };
}

/**
 * The exact update payload for a transition — the lifecycle key and nothing
 * else.
 *
 * Built as a single-key map on purpose: the callable cannot accidentally carry
 * `isActive`, `role`, `halaqaId`, or any payment field along with it. The
 * transition timestamp lives on the audit entry, so no second field is added
 * to `studentProfiles`.
 */
export function buildLifecycleUpdate(
  to: LifecycleValue,
): Record<string, unknown> {
  return { lifecycle: to };
}

/** True when the roster/account/payment dimensions are provably untouched. */
export function isolationHolds(update: Record<string, unknown>): boolean {
  return Object.keys(update).length === 1
    && Object.prototype.hasOwnProperty.call(update, "lifecycle");
}
