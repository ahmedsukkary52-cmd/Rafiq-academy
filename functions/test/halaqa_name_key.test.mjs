/**
 * Halaqa name uniqueness key (pure; no emulator). The Dart mirror reads the
 * same vector table in test/shared/halaqa_name_key_test.dart.
 *
 * Run (after `npm --prefix functions run build`):
 *   node --test functions/test/halaqa_name_key.test.mjs
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { halaqaNameKey, HALAQA_NAME_KEY_VECTORS } = require("../lib/halaqa/halaqaNameKey.js");

test("vector table", () => {
  for (const { input, expected } of HALAQA_NAME_KEY_VECTORS) {
    assert.equal(halaqaNameKey(input), expected, input);
  }
});

test("non-strings and blanks normalize to empty", () => {
  assert.equal(halaqaNameKey(undefined), "");
  assert.equal(halaqaNameKey(42), "");
  assert.equal(halaqaNameKey(" - ! "), "");
});

test("keys never contain a path separator (safe Firestore document id)", () => {
  assert.equal(halaqaNameKey("حلقة/الفجر"), "حلقه الفجر");
  assert.equal(halaqaNameKey("a.b"), "a b");
});
