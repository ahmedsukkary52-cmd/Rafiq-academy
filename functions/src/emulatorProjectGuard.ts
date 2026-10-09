/**
 * Local-safety guard: inside the Functions emulator, every explicit project ID
 * source must name a `demo-*` project. With a real project ID the emulator
 * routes calls for services that are not emulated (Firestore, Auth, Storage,
 * FCM, ...) to that real project, while the backend gate is open.
 *
 * Sources mirror firebase-admin's explicit project ID resolution:
 * app options (filled from FIREBASE_CONFIG), GOOGLE_CLOUD_PROJECT,
 * GCLOUD_PROJECT. All present sources must be demo projects, and at least one
 * must be present; otherwise the emulator is treated as unsafe.
 */

type Env = Record<string, string | undefined>;

const DEMO_PROJECT_ID = /^demo-[a-z0-9-]+$/;

export function isDemoProjectId(projectId: unknown): boolean {
  return typeof projectId === "string" && DEMO_PROJECT_ID.test(projectId);
}

export function isFunctionsEmulator(env: Env = process.env): boolean {
  return env.FUNCTIONS_EMULATOR === "true";
}

/**
 * Returns null when the emulator project is safe, otherwise the reason.
 * [appProjectId] is the initialized Admin app's `options.projectId`, if any.
 */
export function emulatorProjectProblem(
  env: Env = process.env,
  appProjectId?: string | null,
): string | null {
  const candidates: Array<[string, unknown]> = [];
  if (appProjectId !== undefined && appProjectId !== null) {
    candidates.push(["admin app options.projectId", appProjectId]);
  }

  const firebaseConfig = env.FIREBASE_CONFIG;
  if (firebaseConfig !== undefined && firebaseConfig !== "") {
    let parsed: unknown;
    try {
      parsed = JSON.parse(firebaseConfig);
    } catch {
      return "FIREBASE_CONFIG is not inline JSON, so its project ID cannot be verified.";
    }
    const projectId = (parsed as { projectId?: unknown } | null)?.projectId;
    if (projectId !== undefined) {
      candidates.push(["FIREBASE_CONFIG.projectId", projectId]);
    }
  }
  for (const key of ["GOOGLE_CLOUD_PROJECT", "GCLOUD_PROJECT"]) {
    const value = env[key];
    if (value !== undefined && value !== "") candidates.push([key, value]);
  }

  if (candidates.length === 0) {
    return "No project ID could be resolved.";
  }
  const unsafe = candidates.filter(([, id]) => !isDemoProjectId(id));
  if (unsafe.length > 0) {
    return unsafe
      .map(([source, id]) => `${source} is ${JSON.stringify(id)}, not a demo-* project.`)
      .join(" ");
  }
  return null;
}

/** Throws when running in the Functions emulator against a non-demo project. */
export function assertEmulatorProjectIsDemo(
  env: Env = process.env,
  appProjectId?: string | null,
): void {
  if (!isFunctionsEmulator(env)) return;
  const problem = emulatorProjectProblem(env, appProjectId);
  if (problem !== null) {
    throw new Error(
      `Refusing to load Functions in the emulator: ${problem} ` +
        "Start local emulators with `npm run serve` (project demo-rafiq-rules).",
    );
  }
}
