/**
 * Chat message contract (pure) + fail-closed active-role helper.
 * Storage rule constants are checked against the same contract.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const contract = require("../lib/chat/chatMessageContract.js");
const { activeRoleOf } = require("../lib/authority/callerContext.js");

const { parseSendChatMessageInput, validateStoredMedia, messagePreview, ChatInputError } = contract;

const ID = "abcDEF123_-xyz";

function rejects(data, pattern) {
  assert.throws(
    () => parseSendChatMessageInput(data),
    (e) => e instanceof ChatInputError && (!pattern || pattern.test(e.message)),
  );
}

test("text input: trimmed, bounded, type defaults to text", () => {
  const parsed = parseSendChatMessageInput({ conversationId: "a_b", messageId: ID, text: "  مرحبا " });
  assert.deepEqual(parsed, { conversationId: "a_b", messageId: ID, type: "text", text: "مرحبا", media: null });
  rejects({ conversationId: "a_b", messageId: ID, text: "  " });
  rejects({ conversationId: "a_b", messageId: ID, text: "x".repeat(4001) });
  assert.equal(
    parseSendChatMessageInput({ conversationId: "a_b", messageId: ID, text: "x".repeat(4000) }).text.length,
    4000,
  );
});

test("client-owned identity fields are rejected", () => {
  for (const field of ["senderId", "sentAt", "deleted", "participantIds"]) {
    rejects({ conversationId: "a_b", messageId: ID, text: "x", [field]: "v" });
  }
});

test("messageId and conversationId shape", () => {
  rejects({ conversationId: "a_b", messageId: "short", text: "x" });
  rejects({ conversationId: "a_b", messageId: "has/slash/inside", text: "x" });
  rejects({ conversationId: "a/b", messageId: ID, text: "x" });
  rejects({ conversationId: "a_b", messageId: ID, type: "video", text: "x" });
});

test("media path must be the message's own folder for its type", () => {
  const ok = parseSendChatMessageInput({
    conversationId: "a_b",
    messageId: ID,
    type: "image",
    media: { storagePath: `chat_media/a_b/${ID}/p.jpg` },
  });
  assert.equal(ok.media.fileName, "p.jpg");
  rejects({ conversationId: "a_b", messageId: ID, type: "image", media: { storagePath: `chat_voice/a_b/${ID}/p.jpg` } });
  rejects({ conversationId: "a_b", messageId: ID, type: "image", media: { storagePath: `chat_media/c_d/${ID}/p.jpg` } });
  rejects({ conversationId: "a_b", messageId: ID, type: "image", media: { storagePath: `chat_media/a_b/otherMessage1/p.jpg` } });
  rejects({ conversationId: "a_b", messageId: ID, type: "image", media: { storagePath: `chat_media/a_b/${ID}/x/p.jpg` } });
  rejects({ conversationId: "a_b", messageId: ID, type: "image", media: { storagePath: `chat_media/a_b/${ID}/..` } });
  rejects({ conversationId: "a_b", messageId: ID, type: "image" });
  rejects({ conversationId: "a_b", messageId: ID, type: "text", text: "x", media: { storagePath: "p" } });
});

test("voice requires a bounded integer duration", () => {
  const base = { conversationId: "a_b", messageId: ID, type: "voice" };
  const path = `chat_voice/a_b/${ID}/v.m4a`;
  rejects({ ...base, media: { storagePath: path } });
  rejects({ ...base, media: { storagePath: path, durationMs: 0 } });
  rejects({ ...base, media: { storagePath: path, durationMs: 10 * 60 * 1000 + 1 } });
  rejects({ ...base, media: { storagePath: path, durationMs: 1.5 } });
  assert.equal(parseSendChatMessageInput({ ...base, media: { storagePath: path, durationMs: 1200 } }).media.durationMs, 1200);
});

const jpegHead = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
const pdfHead = new Uint8Array([...Buffer.from("%PDF-1.7\n"), 0, 0, 0, 0, 0, 0, 0]);
const m4aHead = new Uint8Array([0, 0, 0, 0x20, ...Buffer.from("ftypM4A "), 0, 0, 0, 0]);

test("stored media: uploader, size, MIME allow-list and signature", () => {
  const base = { type: "image", callerUid: "u1", sizeBytes: 100, contentType: "image/jpeg", uploaderId: "u1", head: jpegHead };
  assert.equal(validateStoredMedia(base), null);
  assert.ok(validateStoredMedia({ ...base, uploaderId: "u2" }));
  assert.ok(validateStoredMedia({ ...base, uploaderId: undefined }));
  assert.ok(validateStoredMedia({ ...base, sizeBytes: 0 }));
  assert.ok(validateStoredMedia({ ...base, sizeBytes: 10 * 1024 * 1024 }));
  assert.ok(validateStoredMedia({ ...base, contentType: "image/gif" }));
  assert.ok(validateStoredMedia({ ...base, head: pdfHead }), "PDF bytes labelled image/jpeg");
  assert.equal(
    validateStoredMedia({ ...base, type: "file", contentType: "application/pdf", head: pdfHead }),
    null,
  );
  assert.ok(validateStoredMedia({ ...base, type: "file", contentType: "text/html", head: pdfHead }));
  assert.equal(
    validateStoredMedia({ ...base, type: "voice", contentType: "audio/mp4", head: m4aHead, sizeBytes: 15 * 1024 * 1024 }),
    null,
  );
  assert.ok(validateStoredMedia({ ...base, type: "voice", contentType: "audio/mp4", head: jpegHead }));
});

test("conversation preview never leaks media details", () => {
  assert.equal(messagePreview("image", ""), "صورة");
  assert.equal(messagePreview("voice", ""), "رسالة صوتية");
  assert.equal(messagePreview("file", ""), "ملف");
  assert.equal(messagePreview("text", "x".repeat(200)).length, 121);
});

test("storage.rules mirrors the contract MIME lists", () => {
  const rules = readFileSync(join(here, "..", "..", "storage.rules"), "utf8");
  for (const [type, policy] of Object.entries(contract.CHAT_MEDIA_POLICY)) {
    assert.ok(rules.includes(`match /${policy.prefix}/{conversationId}/{messageId}/{fileName}`), type);
    for (const mime of Object.keys(policy.contentTypes)) {
      assert.ok(rules.includes(`'${mime}'`), `storage.rules must allow ${mime} for ${type}`);
    }
  }
});

test("activeRoleOf fails closed for deactivated profiles", () => {
  assert.equal(activeRoleOf({ role: "admin", isActive: true }), "admin");
  assert.equal(activeRoleOf({ role: "admin" }), "admin", "legacy profile without isActive");
  assert.equal(activeRoleOf({ role: "admin", isActive: false }), "");
  assert.equal(activeRoleOf(undefined), "");
  assert.equal(activeRoleOf({ isActive: true }), "");
});
