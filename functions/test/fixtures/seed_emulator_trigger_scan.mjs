// Helpers for seed_emulator_triggers_contract.test.mjs. Pure functions over
// source text and deploy endpoints so the test can feed them synthetic
// inputs. Source scanning is text-based, not a TypeScript parser; the
// compiled endpoint manifest is the authority for what is deployed.
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, rmSync, statSync } from "node:fs";
import { join, relative } from "node:path";

export const ALLOWED_FUNCTIONS_MODULES = Object.freeze([
  "firebase-functions/v2/https",
  "firebase-functions/v2/firestore",
  "firebase-functions/v2/scheduler",
  "firebase-functions/params",
]);

const FIRESTORE_EVENT_PREFIX = "google.cloud.firestore.document.v1.";
export const FIRESTORE_FACTORIES = Object.freeze({
  onDocumentCreated: `${FIRESTORE_EVENT_PREFIX}created`,
  onDocumentUpdated: `${FIRESTORE_EVENT_PREFIX}updated`,
  onDocumentDeleted: `${FIRESTORE_EVENT_PREFIX}deleted`,
  onDocumentWritten: `${FIRESTORE_EVENT_PREFIX}written`,
});
const FACTORY_MODULE = { onSchedule: "firebase-functions/v2/scheduler" };
for (const name of Object.keys(FIRESTORE_FACTORIES)) FACTORY_MODULE[name] = "firebase-functions/v2/firestore";

const FACTORY_REFERENCE = /\b(onDocument\w*|onSchedule)\b/g;
const DEFINITION = /\bexport\s+const\s+(\w+)\s*=\s*(onDocument\w*|onSchedule)\s*\(/g;

export function stripComments(text) {
  return text.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'`\\])\/\/.*$/gm, "$1");
}

/** Text of the balanced `{...}` starting at `start`, or null. Skips strings. */
function balancedObject(text, start) {
  if (text[start] !== "{") return null;
  let depth = 0;
  for (let i = start; i < text.length; i++) {
    const ch = text[i];
    if (ch === '"' || ch === "'" || ch === "`") {
      for (i += 1; i < text.length && text[i] !== ch; i++) if (text[i] === "\\") i += 1;
      continue;
    }
    if (ch === "{") depth += 1;
    if (ch === "}" && --depth === 0) return text.slice(start, i + 1);
  }
  return null;
}

function literalOption(options, key) {
  const m = options.match(new RegExp(`\\b${key}\\s*:\\s*(?:"([^"]*)"|'([^']*)'|\`([^\`]*)\`|([^,}\\s]+))`));
  if (!m) return { present: false };
  const value = m[1] ?? m[2] ?? m[3];
  return value === undefined ? { present: true, literal: false, raw: m[4] } : { present: true, literal: true, value };
}

/**
 * Checks how firebase-functions is imported and how triggers are defined:
 *  - only named, un-aliased imports from ALLOWED_FUNCTIONS_MODULES; no
 *    default, namespace, side-effect, dynamic or require() imports and no
 *    re-exports of firebase-functions;
 *  - every reference to onDocument* / onSchedule is either in such an import
 *    or the factory of `export const NAME = factory({ ...literal options })`;
 *    anything else (wrapper, define-then-export, alias, indirect call) is a
 *    problem;
 *  - Firestore triggers need an inline options object with a literal
 *    `document` (`${CONST}` resolved from string constants in the sources).
 * Returns { problems, definitions: { NAME: { file, factory, eventType?, document?, database } } }.
 */
export function scanTriggerSources(sources) {
  const problems = [];
  const files = sources.map(({ file, text }) => ({ file, text: stripComments(text) }));
  const constants = new Map();
  for (const { text } of files) {
    for (const m of text.matchAll(/\bconst\s+([A-Z][A-Z0-9_]*)\s*=\s*"([^"]*)"\s*;/g)) constants.set(m[1], m[2]);
  }
  const definitions = {};

  for (const { file, text } of files) {
    if (/\b(require|import)\s*\(\s*["']firebase-functions/.test(text)) {
      problems.push(`${file}: loads firebase-functions with require() or import(); use a static named import.`);
    }
    if (/\bimport\s*["']firebase-functions/.test(text)) problems.push(`${file}: side-effect import of firebase-functions.`);
    if (/\bexport\s+[^;]*?\bfrom\s*["']firebase-functions/.test(text)) problems.push(`${file}: re-exports firebase-functions.`);

    let importedRefs = 0;
    const imported = new Map();
    for (const m of text.matchAll(/\bimport\s+(type\s+)?([^;]*?)\s+from\s*["']([^"']+)["']/g)) {
      const [, typeOnly, clause, module] = m;
      if (!/^firebase-functions(\/|$)/.test(module)) continue;
      importedRefs += [...clause.matchAll(FACTORY_REFERENCE)].length;
      if (!ALLOWED_FUNCTIONS_MODULES.includes(module)) {
        problems.push(`${file}: imports "${module}", which is not a reviewed firebase-functions module.`);
        continue;
      }
      if (typeOnly) continue;
      const named = clause.trim().match(/^\{([\s\S]*)\}$/);
      if (!named) {
        problems.push(`${file}: "${module}" must be imported with named imports only (no default or namespace import).`);
        continue;
      }
      for (const spec of named[1].split(",").map((s) => s.trim()).filter(Boolean)) {
        if (/\bas\b/.test(spec)) problems.push(`${file}: aliased import "${spec}" from "${module}".`);
        else imported.set(spec.replace(/^type\s+/, ""), module);
      }
    }

    const defs = [...text.matchAll(DEFINITION)];
    const references = [...text.matchAll(FACTORY_REFERENCE)].length;
    if (references !== importedRefs + defs.length) {
      problems.push(
        `${file}: ${references - importedRefs - defs.length} use(s) of onDocument*/onSchedule are not ` +
          '"export const NAME = factory(...)" definitions (wrapper, define-then-export, alias or indirect call).',
      );
    }

    for (const m of defs) {
      const [, name, factory] = m;
      const where = `${file}: ${name}`;
      if (!(factory in FACTORY_MODULE)) {
        problems.push(`${where} uses ${factory}, which is not a reviewed trigger factory.`);
        continue;
      }
      if (imported.get(factory) !== FACTORY_MODULE[factory]) {
        problems.push(`${where} calls ${factory} without a named import from "${FACTORY_MODULE[factory]}".`);
        continue;
      }
      if (name in definitions) problems.push(`${name} is defined twice.`);
      if (factory === "onSchedule") {
        definitions[name] = { file, factory };
        continue;
      }
      const after = m.index + m[0].length;
      const open = text.slice(after).search(/\S/);
      const options = open < 0 ? null : balancedObject(text, after + open);
      if (options === null) {
        problems.push(`${where} must pass an inline options object as the first argument.`);
        continue;
      }
      const document = literalOption(options, "document");
      if (!document.present || !document.literal) {
        problems.push(`${where} has no literal document path.`);
        continue;
      }
      let unresolved = false;
      const path = document.value.replace(/\$\{\s*([A-Za-z_]\w*)\s*\}/g, (_, constName) => {
        if (constants.has(constName)) return constants.get(constName);
        unresolved = true;
        return `\${${constName}}`;
      });
      if (unresolved) problems.push(`${where}: document path ${JSON.stringify(document.value)} has an unresolved constant.`);
      const database = literalOption(options, "database");
      if (database.present && !database.literal) problems.push(`${where}: database is not a literal.`);
      definitions[name] = {
        file,
        factory,
        eventType: FIRESTORE_FACTORIES[factory],
        document: path,
        database: database.present ? database.value : "(default)",
      };
    }
  }
  return { problems, definitions };
}

/** Names exported by `export { a, b } from "..."` lists; aliases and `export *` are problems. */
export function parseIndexExports(text) {
  const problems = [];
  const names = new Set();
  const source = stripComments(text);
  if (/\bexport\s*\*/.test(source)) problems.push("index.ts uses export *.");
  for (const m of source.matchAll(/\bexport\s*\{([^}]*)\}/g)) {
    for (const spec of m[1].split(",").map((s) => s.trim()).filter(Boolean)) {
      if (/\bas\b/.test(spec)) problems.push(`index.ts re-exports with an alias: "${spec}".`);
      else names.add(spec);
    }
  }
  for (const m of source.matchAll(/\bexport\s+(?:const|function|let|var|class)\s+(\w+)/g)) names.add(m[1]);
  return { problems, names };
}

/**
 * Classifies compiled exports by their deploy endpoint (`__endpoint`, what
 * `firebase deploy` and the Functions emulator read). Callables and HTTPS
 * functions run only when called; schedules and Firestore document events
 * are returned for pinning; every other kind is a problem.
 */
export function classifyEndpoints(exportsMap) {
  const problems = [];
  const events = {};
  const schedules = [];
  const callables = [];
  for (const [name, fn] of Object.entries(exportsMap)) {
    const endpoint = typeof fn === "function" ? fn.__endpoint : undefined;
    if (endpoint === null || typeof endpoint !== "object") {
      problems.push(`export ${name} has no deploy endpoint (__endpoint).`);
      continue;
    }
    if (endpoint.platform !== "gcfv2") problems.push(`${name}: platform ${JSON.stringify(endpoint.platform)}; only gcfv2 is reviewed.`);
    const kinds = Object.keys(endpoint).filter((key) => key.endsWith("Trigger"));
    if (kinds.length !== 1) {
      problems.push(`${name}: expected one trigger kind, found ${JSON.stringify(kinds)}.`);
      continue;
    }
    const [kind] = kinds;
    if (kind === "callableTrigger" || kind === "httpsTrigger") {
      callables.push(name);
    } else if (kind === "scheduleTrigger") {
      schedules.push(name);
    } else if (kind === "eventTrigger") {
      const trigger = endpoint.eventTrigger ?? {};
      if (typeof trigger.eventType !== "string" || !trigger.eventType.startsWith(FIRESTORE_EVENT_PREFIX)) {
        problems.push(`${name}: event type ${JSON.stringify(trigger.eventType)} is not a reviewed Firestore document event.`);
        continue;
      }
      events[name] = {
        eventType: trigger.eventType,
        document: trigger.eventFilterPathPatterns?.document ?? trigger.eventFilters?.document,
        database: trigger.eventFilters?.database,
        namespace: trigger.eventFilters?.namespace,
      };
    } else {
      problems.push(`${name}: trigger kind ${kind} is not allowed.`);
    }
  }
  return { problems, events, schedules: schedules.sort(), callables: callables.sort() };
}

/** Differences between classified endpoints and the pinned, reviewed lists. */
export function compareToPinned({ events, schedules }, pinned) {
  const problems = [];
  for (const name of new Set([...Object.keys(events), ...Object.keys(pinned.events)])) {
    const actual = events[name];
    const expected = pinned.events[name];
    if (!expected) problems.push(`new Firestore trigger ${name} on ${actual.document} (${actual.eventType}) is not reviewed.`);
    else if (!actual) problems.push(`reviewed Firestore trigger ${name} is no longer exported.`);
    else {
      for (const key of ["eventType", "document", "database", "namespace"]) {
        if (actual[key] !== expected[key]) {
          problems.push(`${name}: ${key} is ${JSON.stringify(actual[key])}, reviewed ${JSON.stringify(expected[key])}.`);
        }
      }
    }
  }
  const pinnedSchedules = [...pinned.schedules].sort();
  if (JSON.stringify(schedules) !== JSON.stringify(pinnedSchedules)) {
    problems.push(`scheduled functions are ${JSON.stringify(schedules)}, reviewed ${JSON.stringify(pinnedSchedules)}.`);
  }
  return problems;
}

/**
 * Source definitions exported from index.ts must equal the compiled event
 * and schedule endpoints: a mismatch means a stale lib/ build or a trigger
 * defined in a form the source scan does not understand.
 */
export function crossCheck({ definitions, indexNames, events, schedules }) {
  const problems = [];
  const exported = Object.entries(definitions).filter(([name]) => indexNames.has(name));
  const sourceEvents = Object.fromEntries(exported.filter(([, d]) => d.factory !== "onSchedule"));
  const sourceSchedules = exported.filter(([, d]) => d.factory === "onSchedule").map(([name]) => name).sort();
  for (const name of new Set([...Object.keys(sourceEvents), ...Object.keys(events)])) {
    const src = sourceEvents[name];
    const lib = events[name];
    if (!lib) problems.push(`${name} is a trigger in src but not in lib/ (stale build?).`);
    else if (!src) problems.push(`${name} is a trigger in lib/ but not found in src as a reviewed definition.`);
    else {
      for (const key of ["eventType", "document", "database"]) {
        if (src[key] !== lib[key]) {
          problems.push(`${name}: src ${key} ${JSON.stringify(src[key])} differs from lib ${JSON.stringify(lib[key])} (stale build?).`);
        }
      }
    }
  }
  if (JSON.stringify(sourceSchedules) !== JSON.stringify(schedules)) {
    problems.push(`schedules in src ${JSON.stringify(sourceSchedules)} differ from lib ${JSON.stringify(schedules)}.`);
  }
  return problems;
}

/**
 * Compiles `projectDir` with the project's own TypeScript into `outDir` and
 * throws unless tsc exits 0. tsc still emits JavaScript when type checking
 * fails (no noEmitOnError), so emitted or newer files alone never count as a
 * successful build.
 */
export function compileWithTsc({ functionsDir, projectDir = functionsDir, outDir }) {
  const tsc = join(functionsDir, "node_modules", "typescript", "bin", "tsc");
  const res = spawnSync(process.execPath, [tsc, "-p", join(projectDir, "tsconfig.json"), "--outDir", outDir], {
    cwd: projectDir,
    encoding: "utf8",
    timeout: 180000,
  });
  if (res.status !== 0) {
    const reason = res.error ? res.error.message : `exit ${res.status ?? res.signal}`;
    throw new Error(`tsc failed (${reason}); its output is not a valid build.\n${res.stdout ?? ""}${res.stderr ?? ""}`);
  }
}

/**
 * Compiles into a new directory under `parentDir` and returns it. When tsc
 * fails the directory is removed here before the error is rethrown, so
 * cleanup does not depend on the test runner's after hooks.
 */
export function compileIntoTempDir({ functionsDir, projectDir = functionsDir, parentDir, prefix }) {
  mkdirSync(parentDir, { recursive: true });
  const outDir = mkdtempSync(join(parentDir, prefix));
  try {
    compileWithTsc({ functionsDir, projectDir, outDir });
    return outDir;
  } catch (error) {
    rmSync(outDir, { recursive: true, force: true });
    throw error;
  }
}

/** src/**\/*.ts files whose lib/**\/*.js output is missing or older. */
export function findStaleOutputs(srcDir, libDir) {
  const stale = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith(".ts") && !entry.name.endsWith(".d.ts")) {
        const rel = relative(srcDir, path);
        const out = join(libDir, rel.replace(/\.ts$/, ".js"));
        if (!existsSync(out)) stale.push(`${rel} (no ${relative(libDir, out)})`);
        else if (statSync(out).mtimeMs < statSync(path).mtimeMs) stale.push(`${rel} (newer than its lib/ output)`);
      }
    }
  };
  walk(srcDir);
  return stale.map((s) => s.replaceAll("\\", "/")).sort();
}
