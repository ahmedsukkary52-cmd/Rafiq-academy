/**
 * Resolve the Flutter client's Cloud Functions region without assuming a
 * string literal inside di_module.dart (which may use `functionsRegion`).
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..", "..");

export function clientFunctionsRegion() {
  const appFirebase = readFileSync(
    join(repoRoot, "lib", "core", "firebase", "app_firebase.dart"),
    "utf8",
  );
  const regionConst = appFirebase.match(
    /const\s+String\s+functionsRegion\s*=\s*'([^']+)'/,
  );
  if (!regionConst) {
    throw new Error("functionsRegion missing from lib/core/firebase/app_firebase.dart");
  }
  const declared = regionConst[1];

  const di = readFileSync(join(repoRoot, "lib", "core", "di", "di_module.dart"), "utf8");
  const literal = [...di.matchAll(/FirebaseFunctions\.instanceFor\(\s*region:\s*'([^']+)'/g)].map(
    (m) => m[1],
  );
  const usesConst = /FirebaseFunctions\.instanceFor\([\s\S]*?region:\s*functionsRegion/.test(di);
  if (literal.length === 0 && !usesConst) {
    throw new Error("di_module.dart does not configure FirebaseFunctions.instanceFor");
  }
  if (literal.some((r) => r !== declared)) {
    throw new Error(`DI literal regions ${JSON.stringify(literal)} != ${declared}`);
  }
  return declared;
}
