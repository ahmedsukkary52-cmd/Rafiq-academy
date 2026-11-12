/**
 * Academy username / temporary-password generation (pure).
 * Run: node --test functions/test/academy_credentials.test.mjs (after build).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const c = require("../lib/accounts/academyCredentials.js");

test("usernames carry a role prefix and six digits", () => {
  for (const [role, prefix] of Object.entries(c.USERNAME_PREFIX)) {
    const name = c.generateUsername(role);
    assert.match(name, new RegExp(`^${prefix}\\d{6}$`));
    assert.equal(c.isValidUsername(name), true);
  }
  assert.equal(c.generateUsername("student", () => 42), "st000042");
});

test("login email lives under the reserved .invalid domain", () => {
  assert.equal(c.loginEmailFor(" ST000042 "), "st000042@members.rafiq-academy.invalid");
  assert.equal(c.isInternalLoginEmail("st000042@members.rafiq-academy.invalid"), true);
  assert.equal(c.isInternalLoginEmail("someone@gmail.com"), false);
  assert.equal(c.isValidUsername("a@b.com"), false);
  assert.equal(c.isValidUsername("ab"), false);
});

test("temporary passwords: length, letter + digit, unambiguous, varied", () => {
  const seen = new Set();
  for (let i = 0; i < 300; i++) {
    const p = c.generateTemporaryPassword();
    assert.equal(p.length, c.TEMP_PASSWORD_LENGTH);
    assert.match(p, /[A-Za-z]/);
    assert.match(p, /[2-9]/);
    assert.doesNotMatch(p, /[0O1lI]/);
    seen.add(p);
  }
  assert.equal(seen.size, 300);
});

test("member password policy", () => {
  assert.notEqual(c.memberPasswordProblem("abc12"), null);
  assert.notEqual(c.memberPasswordProblem("abcdefgh"), null);
  assert.notEqual(c.memberPasswordProblem("12345678"), null);
  assert.equal(c.memberPasswordProblem("abcd1234"), null);
  assert.equal(c.memberPasswordProblem("سلام1234"), null);
});
