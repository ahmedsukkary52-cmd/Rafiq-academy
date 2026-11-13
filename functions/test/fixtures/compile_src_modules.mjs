// Compiles selected self-contained functions/src modules with the project's
// own tsc (functions/tsconfig.json: strict, full type check) into a private
// directory under os.tmpdir() and loads them from there. Unit tests of pure
// modules therefore neither need `npm run build` nor read or write lib/
// (what `npm run serve` loads and deploy uploads).
//
// Only for modules whose imports are other listed modules or Node built-ins:
// the temporary directory sits outside functions/, so packages from
// node_modules do not resolve from it.
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { compileWithTsc } from "./seed_emulator_trigger_scan.mjs";

const require = createRequire(import.meta.url);
const functionsDir = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const srcDir = join(functionsDir, "src");

/**
 * Compiles `modules` (paths under src/ without `.ts`, e.g. "quran/quranPosition")
 * and returns `{ load(module), dispose() }`. tsc must exit 0; on failure the
 * directory is removed before the error is rethrown. Call `dispose` from an
 * `after` hook to remove it after the tests.
 */
export function compileSrcModules(modules, { prefix = "functions-src-modules-" } = {}) {
  const root = mkdtempSync(join(tmpdir(), prefix));
  const dispose = () => rmSync(root, { recursive: true, force: true });
  try {
    writeFileSync(
      join(root, "tsconfig.json"),
      JSON.stringify({
        extends: join(functionsDir, "tsconfig.json"),
        compilerOptions: { rootDir: srcDir, types: [] },
        files: modules.map((module) => join(srcDir, `${module}.ts`)),
        include: [],
      }),
    );
    const outDir = join(root, "lib");
    compileWithTsc({ functionsDir, projectDir: root, outDir });
    return { load: (module) => require(join(outDir, `${module}.js`)), dispose };
  } catch (error) {
    dispose();
    throw error;
  }
}
