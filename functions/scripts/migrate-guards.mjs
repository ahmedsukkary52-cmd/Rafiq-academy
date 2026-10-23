// Pre-flight checks shared by the one-off data migrations
// (migrate-contact-fields.mjs, migrate-email-backfill.mjs). Pure: callers
// pass argv, env and the credential file's project id, so every refusal is
// unit-testable. Nothing here loads firebase-admin or touches the network.
//
// Problem messages name flags, env var names and project ids only; argument
// values that are not a project id or confirmation token are never echoed.

/** The only projects a migration may target (.firebaserc aliases + the emulator demo). */
export const ALLOWED_PROJECTS = Object.freeze([
  "rafiq-academy",
  "rafiq-academy-staging",
  "rafiq-academy-prod",
  "demo-rafiq-rules",
]);

const PROJECT_ENV_KEYS = [
  "GOOGLE_CLOUD_PROJECT",
  "GCLOUD_PROJECT",
  "GCP_PROJECT",
  "CLOUDSDK_CORE_PROJECT",
];

const LOOPBACK_HOST = /^(127\.0\.0\.1|localhost):\d{1,5}$/;
const PROJECT_ID = /^[a-z][a-z0-9-]{4,61}[a-z0-9]$/;

/** Apply mode requires `--confirm <scriptId>:<projectId>` typed exactly. */
export function confirmationToken(scriptId, projectId) {
  return `${scriptId}:${projectId}`;
}

/** Parses `[--project <id>] [--dry-run | --apply --confirm <token>]`. */
export function parseMigrationArgs(argv) {
  const out = { project: null, apply: false, dryRun: false, confirm: null, problems: [] };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      out.problems.push(`Unexpected positional argument #${i + 1}.`);
      continue;
    }
    const eq = arg.indexOf("=");
    const flag = eq === -1 ? arg : arg.slice(0, eq);
    const inline = eq === -1 ? undefined : arg.slice(eq + 1);
    const takeValue = () => {
      if (inline !== undefined) return inline;
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) return null;
      i += 1;
      return next;
    };
    switch (flag) {
      case "--project":
        out.project = takeValue();
        if (out.project === null) out.problems.push("--project needs a value.");
        break;
      case "--confirm":
        out.confirm = takeValue();
        if (out.confirm === null) out.problems.push("--confirm needs a value.");
        break;
      case "--apply":
      case "--dry-run":
        if (inline !== undefined) out.problems.push(`${flag} takes no value.`);
        if (flag === "--apply") out.apply = true;
        else out.dryRun = true;
        break;
      default:
        out.problems.push(
          PROJECT_ID.test(flag.slice(2)) ? `Unknown flag --${flag.slice(2)}.` : "Unknown flag.",
        );
    }
  }
  return out;
}

/** Project id from a service-account JSON, or a problem. Never returns file contents. */
export function credentialFileProjectId(env, readFile) {
  const path = env.GOOGLE_APPLICATION_CREDENTIALS;
  if (path === undefined || path === "") return { projectId: null, problem: null };
  try {
    const parsed = JSON.parse(readFile(path));
    const projectId = typeof parsed?.project_id === "string" ? parsed.project_id : null;
    return { projectId, problem: null };
  } catch {
    return { projectId: null, problem: "GOOGLE_APPLICATION_CREDENTIALS could not be read as JSON." };
  }
}

/**
 * Returns { problems, mode }. mode is "dry-run" unless --apply was given
 * with the exact confirmation token; it is null whenever problems exist.
 */
export function checkMigrationTarget({ scriptId, args, env, credentialProjectId, needsAuth }) {
  const problems = [...args.problems];
  const project = args.project;

  if (!project) {
    problems.push(`--project is required (one of: ${ALLOWED_PROJECTS.join(", ")}).`);
  } else if (!ALLOWED_PROJECTS.includes(project)) {
    problems.push(
      PROJECT_ID.test(project)
        ? `Project "${project}" is not in the migration allowlist.`
        : "--project is not a valid project id.",
    );
  }

  if (project) {
    for (const key of PROJECT_ENV_KEYS) {
      const value = env[key];
      if (value !== undefined && value !== "" && value !== project) {
        problems.push(`${key} names a different project than --project.`);
      }
    }
    if (env.FIREBASE_CONFIG !== undefined && env.FIREBASE_CONFIG !== "") {
      let parsed;
      try {
        parsed = JSON.parse(env.FIREBASE_CONFIG);
      } catch {
        parsed = undefined;
      }
      if (parsed?.projectId !== project) {
        problems.push("FIREBASE_CONFIG does not name --project as its projectId.");
      }
    }
    if (credentialProjectId !== null && credentialProjectId !== undefined && credentialProjectId !== project) {
      problems.push("GOOGLE_APPLICATION_CREDENTIALS belongs to a different project than --project.");
    }

    const emulatorKeys = ["FIRESTORE_EMULATOR_HOST", ...(needsAuth ? ["FIREBASE_AUTH_EMULATOR_HOST"] : [])];
    const isDemo = project.startsWith("demo-");
    if (isDemo) {
      for (const key of emulatorKeys) {
        if (!LOOPBACK_HOST.test(env[key] ?? "")) {
          problems.push(`${project} is emulator-only; ${key} must point at a loopback emulator.`);
        }
      }
    } else {
      for (const key of Object.keys(env)) {
        if (key.toUpperCase().endsWith("_EMULATOR_HOST") && env[key]) {
          problems.push(`${key} is set while targeting a real project; unset it or use a demo- project.`);
        }
      }
    }
  }

  if (args.apply && args.dryRun) {
    problems.push("--apply and --dry-run cannot be combined.");
  }
  if (args.apply) {
    const expected = project ? confirmationToken(scriptId, project) : `${scriptId}:<project>`;
    if (args.confirm !== expected) {
      problems.push(`--apply needs --confirm ${expected}`);
    }
  } else if (args.confirm !== null) {
    problems.push("--confirm is only accepted together with --apply.");
  }

  return { problems, mode: problems.length > 0 ? null : args.apply ? "apply" : "dry-run" };
}

const GRPC_CODES = {
  5: "not-found",
  6: "already-exists",
  7: "permission-denied",
  9: "failed-precondition",
  10: "aborted",
  14: "unavailable",
  16: "unauthenticated",
};

/** Error code only; messages can quote document data and are never printed. */
export function safeErrorCode(error) {
  const code = error?.code;
  if (typeof code === "number") return GRPC_CODES[code] ?? `grpc-${code}`;
  if (typeof code === "string" && /^[a-z0-9/_-]{1,60}$/i.test(code)) return code;
  return "unknown";
}

/** UID-shaped document ids only; anything else is never printed. */
export function isSafeId(id) {
  return typeof id === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(id);
}

/** Capped list of safe ids for operator review. */
export function createIdList(cap = 50) {
  const ids = [];
  let total = 0;
  let unprintable = 0;
  return {
    add(id) {
      total += 1;
      if (!isSafeId(id)) unprintable += 1;
      else if (ids.length < cap) ids.push(id);
    },
    toJSON() {
      return { total, ids, truncated: total - unprintable > ids.length, unprintable };
    },
  };
}

export function bump(counts, key, by = 1) {
  counts[key] = (counts[key] ?? 0) + by;
}
