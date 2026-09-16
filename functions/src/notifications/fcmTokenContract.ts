/**
 * WA-13 / C11 — FCM device token contract (pure logic, no Firebase imports).
 *
 * Path: `fcmTokens/{uid}/devices/{deviceId}`.
 * Client may create/update/delete only its own device docs (Firestore Rules).
 * Server (Admin SDK) owns disable/telemetry fields listed in
 * [FCM_SERVER_FIELDS] — Rules deny those keys to clients.
 */

export const FCM_TOKENS_COLLECTION = "fcmTokens";
export const FCM_DEVICES_SUBCOLLECTION = "devices";
export const NOTIFICATIONS_COLLECTION = "notifications";
export const NOTIFICATION_DELIVERIES_COLLECTION = "notificationDeliveries";
export const PARENT_PROFILES_COLLECTION = "parentProfiles";
export const USERS_COLLECTION = "users";

export const FCM_PLATFORMS = ["android", "ios", "web"] as const;
export type FcmPlatform = (typeof FCM_PLATFORMS)[number];

/** Client-writable device fields — Firestore Rules enforce the same list. */
export const FCM_CLIENT_FIELDS = [
  "token",
  "platform",
  "createdAt",
  "updatedAt",
  "disabled",
] as const;

/** Server-owned device fields — never client-writable. */
export const FCM_SERVER_FIELDS = [
  "disabledReason",
  "disabledAt",
  "lastSendAt",
  "lastErrorCode",
] as const;

/** Bounded fan-out per recipient — protects send cost and payload size. */
export const MAX_TOKENS_PER_RECIPIENT = 20;
export const MAX_TOKEN_LENGTH = 4096;

export type DeviceTokenDoc = {
  deviceId: string;
  token?: unknown;
  platform?: unknown;
  disabled?: unknown;
};

export type SendableToken = { deviceId: string; token: string };

export function isSupportedPlatform(value: unknown): value is FcmPlatform {
  return (
    typeof value === "string" &&
    (FCM_PLATFORMS as readonly string[]).includes(value)
  );
}

export function isUsableToken(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.trim().length > 0 &&
    value.length <= MAX_TOKEN_LENGTH
  );
}

/**
 * Deterministic, bounded set of tokens to push to.
 *
 * Skips disabled devices and malformed tokens, de-duplicates the same token
 * registered under multiple device ids, and caps fan-out. Ordering is by
 * deviceId so repeated executions select the same devices.
 */
export function selectSendableTokens(
  devices: readonly DeviceTokenDoc[],
): SendableToken[] {
  const sorted = [...devices].sort((a, b) =>
    String(a.deviceId).localeCompare(String(b.deviceId)),
  );

  const seen = new Set<string>();
  const selected: SendableToken[] = [];

  for (const device of sorted) {
    if (device.disabled === true) continue;
    if (!isUsableToken(device.token)) continue;

    const token = device.token.trim();
    if (seen.has(token)) continue;
    seen.add(token);

    selected.push({ deviceId: String(device.deviceId), token });
    if (selected.length >= MAX_TOKENS_PER_RECIPIENT) break;
  }

  return selected;
}

/**
 * FCM error codes that prove the token itself is dead.
 *
 * `messaging/invalid-argument` is intentionally excluded: it is also raised for
 * malformed payloads, and disabling every device on a payload bug would be a
 * silent outage. Those are reported as retriable instead.
 */
export const UNREGISTERED_ERROR_CODES = [
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
] as const;

export function isUnregisteredTokenError(code: unknown): boolean {
  return (
    typeof code === "string" &&
    (UNREGISTERED_ERROR_CODES as readonly string[]).includes(code)
  );
}

export type SendOutcome = {
  deviceId: string;
  success: boolean;
  errorCode?: string;
};

export type DeliveryStatus = "sent" | "partial" | "failed" | "no_tokens";

export type DeliverySummary = {
  status: DeliveryStatus;
  successCount: number;
  failureCount: number;
  /** Devices to disable — token proven dead. */
  invalidDeviceIds: string[];
  /** Devices that failed for other reasons — kept, surfaced to logs. */
  retriableDeviceIds: string[];
  errorCodes: string[];
};

/** Classifies per-token results; partial failures are never swallowed. */
export function summarizeSendOutcomes(
  outcomes: readonly SendOutcome[],
): DeliverySummary {
  if (outcomes.length === 0) {
    return {
      status: "no_tokens",
      successCount: 0,
      failureCount: 0,
      invalidDeviceIds: [],
      retriableDeviceIds: [],
      errorCodes: [],
    };
  }

  const invalidDeviceIds: string[] = [];
  const retriableDeviceIds: string[] = [];
  const errorCodes: string[] = [];
  let successCount = 0;

  for (const outcome of outcomes) {
    if (outcome.success) {
      successCount += 1;
      continue;
    }
    if (outcome.errorCode && !errorCodes.includes(outcome.errorCode)) {
      errorCodes.push(outcome.errorCode);
    }
    if (isUnregisteredTokenError(outcome.errorCode)) {
      invalidDeviceIds.push(outcome.deviceId);
    } else {
      retriableDeviceIds.push(outcome.deviceId);
    }
  }

  const failureCount = outcomes.length - successCount;
  const status: DeliveryStatus =
    failureCount === 0 ? "sent" : successCount === 0 ? "failed" : "partial";

  return {
    status,
    successCount,
    failureCount,
    invalidDeviceIds,
    retriableDeviceIds,
    errorCodes,
  };
}
