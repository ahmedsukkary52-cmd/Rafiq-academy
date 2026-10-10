// Runs the seeder in-process with the firebase-admin module spy active but
// without any Node preload option (the seeder refuses those). Used by
// seed_emulator_run.test.mjs. SPY_CONTROL=1 loads firebase-admin directly as
// the spy's positive control instead.
import { createRequire } from "node:module";

createRequire(import.meta.url)("./seed_emulator_module_spy.cjs");

if (process.env.SPY_CONTROL === "1") {
  await import("firebase-admin/app");
} else {
  const { runSeed } = await import("../../scripts/seed-emulator.mjs");
  process.exitCode = await runSeed({ args: process.argv.slice(2) });
}
