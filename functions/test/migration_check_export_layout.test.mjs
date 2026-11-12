/**
 * Export layout check run before importing a managed export into the
 * emulator (RELEASE_RUNBOOK_J10.md §3). Fixtures are empty files in temporary
 * folders laid out like the exports; no emulator and no network.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { ALL_KINDS_METADATA, checkExportLayout } from "../scripts/migration-check-export-layout.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const SCRIPT = join(here, "..", "scripts", "migration-check-export-layout.mjs");

function fixture(t, name, files) {
  const root = mkdtempSync(join(tmpdir(), "export-layout-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const dir = join(root, name);
  for (const file of files) {
    mkdirSync(dirname(join(dir, file)), { recursive: true });
    writeFileSync(join(dir, file), "");
  }
  mkdirSync(dir, { recursive: true });
  return dir;
}

const FULL = (name) => [
  `${name}.overall_export_metadata`,
  `all_namespaces/all_kinds/${ALL_KINDS_METADATA}`,
  "all_namespaces/all_kinds/output-0",
  "all_namespaces/all_kinds/output-1",
];

test("a full managed export is accepted", (t) => {
  const dir = fixture(t, "rafiq-release-20261028-1500", FULL("rafiq-release-20261028-1500"));
  assert.deepEqual(checkExportLayout(dir), { layout: "full", ok: true, problems: [] });
});

test("the emulator's own export layout is the same full layout", (t) => {
  const dir = fixture(t, "firestore_export", FULL("firestore_export"));
  assert.equal(checkExportLayout(dir).ok, true);
});

test("a --collection-ids export (kind_* folders) is refused", (t) => {
  const name = "rafiq-release-20261028-1500";
  const dir = fixture(t, name, [
    `${name}.overall_export_metadata`,
    "all_namespaces/kind_halaqat/all_namespaces_kind_halaqat.export_metadata",
    "all_namespaces/kind_halaqat/output-0",
    "all_namespaces/kind_users/all_namespaces_kind_users.export_metadata",
    "all_namespaces/kind_users/output-0",
  ]);
  const result = checkExportLayout(dir);
  assert.equal(result.layout, "collection");
  assert.equal(result.ok, false);
  assert.match(result.problems.join(" "), /without --collection-ids/);
});

test("a parent folder or a renamed folder is refused", (t) => {
  const name = "rafiq-release-20261028-1500";
  const dir = fixture(t, name, FULL(name));
  const parent = dirname(dir);
  assert.equal(checkExportLayout(parent).ok, false, "the folder holding the export");

  const renamed = fixture(t, "backup", FULL(name));
  assert.match(checkExportLayout(renamed).problems.join(" "), /backup\.overall_export_metadata/);
});

test("missing metadata or data files are refused", (t) => {
  const name = "export";
  const noOverall = fixture(t, name, FULL(name).slice(1));
  assert.equal(checkExportLayout(noOverall).ok, false);

  const noKindMetadata = fixture(t, name, FULL(name).filter((f) => !f.endsWith(ALL_KINDS_METADATA)));
  assert.match(checkExportLayout(noKindMetadata).problems.join(" "), /export_metadata missing/);

  const noOutput = fixture(t, name, FULL(name).filter((f) => !f.includes("output-")));
  assert.match(checkExportLayout(noOutput).problems.join(" "), /no output-N/);

  const empty = fixture(t, name, []);
  assert.equal(checkExportLayout(empty).layout, "unknown");
  assert.equal(checkExportLayout(join(empty, "absent")).layout, "missing");
});

test("CLI: exit 0 for a full export, 1 otherwise, one JSON line", (t) => {
  const good = fixture(t, "export", FULL("export"));
  const ok = spawnSync(process.execPath, [SCRIPT, good], { encoding: "utf8" });
  assert.equal(ok.status, 0, ok.stderr);
  assert.deepEqual(JSON.parse(ok.stdout), { layout: "full", ok: true, problems: [] });

  const bad = spawnSync(process.execPath, [SCRIPT], { encoding: "utf8" });
  assert.equal(bad.status, 1);
  assert.equal(JSON.parse(bad.stdout).ok, false);
});

test("the checker reads directory names only and imports no Firebase module", () => {
  const source = readFileSync(SCRIPT, "utf8");
  const imports = [...source.matchAll(/^import .* from "([^"]+)";/gm)].map((m) => m[1]);
  assert.deepEqual(imports.sort(), ["node:fs", "node:path", "node:url"]);
  assert.doesNotMatch(source, /readFileSync|createReadStream|openSync/);
});
