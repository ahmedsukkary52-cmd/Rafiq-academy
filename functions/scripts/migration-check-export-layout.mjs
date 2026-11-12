// Checks the folder layout of a downloaded Firestore managed export before it
// is imported into the emulator for migration-inspect-release-data.mjs. Reads
// directory names only, never file contents, and needs no Firebase access.
//
//   node scripts/migration-check-export-layout.mjs <export folder>
//
// Accepts only the full-export layout (`all_namespaces/all_kinds`), the one
// the release rehearsal imported with `firebase emulators:exec --import`.
// A `--collection-ids` export writes `all_namespaces/kind_<collection>`
// folders instead and is refused. Exit 0 when the layout is accepted, 1
// otherwise; one JSON line on stdout either way.
import { existsSync, readdirSync, statSync } from "node:fs";
import { basename, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export const ALL_KINDS_METADATA = "all_namespaces_all_kinds.export_metadata";

export function checkExportLayout(dir) {
  if (typeof dir !== "string" || dir === "" || !existsSync(dir) || !statSync(dir).isDirectory()) {
    return { layout: "missing", ok: false, problems: ["export folder not found"] };
  }
  const problems = [];
  const name = basename(resolve(dir));
  const overall = readdirSync(dir).filter((entry) => entry.endsWith(".overall_export_metadata"));
  if (overall.length !== 1 || overall[0] !== `${name}.overall_export_metadata`) {
    problems.push(`expected exactly one ${name}.overall_export_metadata in the folder`);
  }

  const namespaces = join(dir, "all_namespaces");
  const kinds = existsSync(namespaces) && statSync(namespaces).isDirectory() ? readdirSync(namespaces) : [];
  let layout = "unknown";
  if (kinds.some((kind) => kind.startsWith("kind_"))) {
    layout = "collection";
    problems.push("collection export (kind_* folders): export again without --collection-ids");
  } else if (kinds.includes("all_kinds")) {
    layout = "full";
    const files = readdirSync(join(namespaces, "all_kinds"));
    if (!files.includes(ALL_KINDS_METADATA)) problems.push(`all_kinds/${ALL_KINDS_METADATA} missing`);
    if (!files.some((file) => /^output-\d+$/.test(file))) problems.push("all_kinds has no output-N file");
  } else {
    problems.push("all_namespaces/all_kinds missing");
  }
  return { layout, ok: problems.length === 0, problems };
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  const args = process.argv.slice(2);
  const result = args.length === 1
    ? checkExportLayout(args[0])
    : { layout: "missing", ok: false, problems: ["usage: migration-check-export-layout.mjs <export folder>"] };
  console.log(JSON.stringify(result));
  process.exitCode = result.ok ? 0 : 1;
}
