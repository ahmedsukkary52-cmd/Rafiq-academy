/**
 * Chat message contract (pure) — shared by sendChatMessage, edit, delete and
 * mirrored by storage.rules (paths, MIME allow-lists, size ceilings).
 */

import {
  CONTACT_INFO_REJECTION_MESSAGE,
  detectContactInfo,
} from "../privacy/contactInfoPolicy";

export type ChatMessageType = "text" | "image" | "voice" | "file";

export const CHAT_MESSAGE_TYPES: readonly ChatMessageType[] = [
  "text",
  "image",
  "voice",
  "file",
];

export const CHAT_TEXT_MAX_CHARS = 4000;
export const CHAT_PREVIEW_MAX_CHARS = 120;
export const CHAT_FILE_NAME_MAX_CHARS = 120;
export const CHAT_VOICE_MAX_DURATION_MS = 10 * 60 * 1000;
export const CHAT_MESSAGE_ID_PATTERN = /^[A-Za-z0-9_-]{10,40}$/;
export const CHAT_DELETED_PREVIEW = "تم حذف هذه الرسالة";

type MediaType = Exclude<ChatMessageType, "text">;

type Signature = { offset: number; bytes: number[] };

const ascii = (s: string): number[] => [...s].map((c) => c.charCodeAt(0));

const SIG = {
  jpeg: [{ offset: 0, bytes: [0xff, 0xd8, 0xff] }],
  png: [{ offset: 0, bytes: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] }],
  webp: [
    { offset: 0, bytes: ascii("RIFF") },
    { offset: 8, bytes: ascii("WEBP") },
  ],
  isoMedia: [{ offset: 4, bytes: ascii("ftyp") }],
  adts1: [{ offset: 0, bytes: [0xff, 0xf1] }],
  adts9: [{ offset: 0, bytes: [0xff, 0xf9] }],
  id3: [{ offset: 0, bytes: ascii("ID3") }],
  mpegFrameB: [{ offset: 0, bytes: [0xff, 0xfb] }],
  mpegFrame3: [{ offset: 0, bytes: [0xff, 0xf3] }],
  mpegFrame2: [{ offset: 0, bytes: [0xff, 0xf2] }],
  ogg: [{ offset: 0, bytes: ascii("OggS") }],
  webm: [{ offset: 0, bytes: [0x1a, 0x45, 0xdf, 0xa3] }],
  wav: [
    { offset: 0, bytes: ascii("RIFF") },
    { offset: 8, bytes: ascii("WAVE") },
  ],
  pdf: [{ offset: 0, bytes: ascii("%PDF-") }],
  ole: [{ offset: 0, bytes: [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1] }],
  zip: [{ offset: 0, bytes: [0x50, 0x4b, 0x03, 0x04] }],
} satisfies Record<string, Signature[]>;

const MP3 = [SIG.id3, SIG.mpegFrameB, SIG.mpegFrame3, SIG.mpegFrame2];
const MP4_AUDIO = [SIG.isoMedia];

/** Allowed content types per media type → accepted file signatures. */
export const CHAT_MEDIA_POLICY: Record<
  MediaType,
  {
    prefix: "chat_media" | "chat_voice" | "chat_attachments";
    maxBytes: number;
    contentTypes: Record<string, Signature[][]>;
  }
> = {
  image: {
    prefix: "chat_media",
    maxBytes: 10 * 1024 * 1024,
    contentTypes: {
      "image/jpeg": [SIG.jpeg],
      "image/png": [SIG.png],
      "image/webp": [SIG.webp],
    },
  },
  voice: {
    prefix: "chat_voice",
    maxBytes: 20 * 1024 * 1024,
    contentTypes: {
      "audio/mp4": MP4_AUDIO,
      "audio/m4a": MP4_AUDIO,
      "audio/x-m4a": MP4_AUDIO,
      "audio/aac": [SIG.adts1, SIG.adts9, SIG.isoMedia],
      "audio/mpeg": MP3,
      "audio/ogg": [SIG.ogg],
      "audio/webm": [SIG.webm],
      "audio/wav": [SIG.wav],
      "audio/x-wav": [SIG.wav],
    },
  },
  file: {
    prefix: "chat_attachments",
    maxBytes: 10 * 1024 * 1024,
    contentTypes: {
      "application/pdf": [SIG.pdf],
      "application/msword": [SIG.ole],
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
        [SIG.zip],
    },
  },
};

/** Bytes needed from the object head to evaluate every signature. */
export const CHAT_SIGNATURE_HEAD_BYTES = 16;

export class ChatInputError extends Error {
  constructor(
    readonly code: "invalid-argument" | "failed-precondition",
    message: string,
  ) {
    super(message);
  }
}

export type ParsedSendInput = {
  conversationId: string;
  messageId: string;
  type: ChatMessageType;
  text: string;
  media: null | {
    storagePath: string;
    fileName: string;
    durationMs: number | null;
  };
};

function nonEmptyId(raw: unknown, field: string): string {
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new ChatInputError("invalid-argument", `${field} مطلوب`);
  }
  const value = raw.trim();
  if (value.includes("/") || value.length > 200) {
    throw new ChatInputError("invalid-argument", `${field} غير صالح`);
  }
  return value;
}

export function isChatMessageType(raw: unknown): raw is ChatMessageType {
  return (
    typeof raw === "string"
    && (CHAT_MESSAGE_TYPES as readonly string[]).includes(raw)
  );
}

export function normalizeMessageText(raw: unknown): string {
  if (raw === undefined || raw === null) return "";
  if (typeof raw !== "string") {
    throw new ChatInputError("invalid-argument", "نص الرسالة غير صالح");
  }
  const text = raw.trim();
  if (text.length > CHAT_TEXT_MAX_CHARS) {
    throw new ChatInputError(
      "invalid-argument",
      `الرسالة أطول من ${CHAT_TEXT_MAX_CHARS} حرف`,
    );
  }
  if (detectContactInfo(text) !== null) {
    throw new ChatInputError("invalid-argument", CONTACT_INFO_REJECTION_MESSAGE);
  }
  return text;
}

function isSafeFileName(name: string): boolean {
  return (
    name.length > 0
    && name.length <= CHAT_FILE_NAME_MAX_CHARS
    && !name.includes("/")
    && !name.includes("\\")
    && name !== "."
    && name !== ".."
    // eslint-disable-next-line no-control-regex
    && !/[\u0000-\u001f\u007f]/.test(name)
  );
}

/** `{prefix}/{conversationId}/{messageId}/{fileName}` — exact, no nesting. */
export function expectedMediaPathParts(
  storagePath: string,
): { prefix: string; conversationId: string; messageId: string; fileName: string } | null {
  const parts = storagePath.split("/");
  if (parts.length !== 4) return null;
  const [prefix, conversationId, messageId, fileName] = parts;
  if (!prefix || !conversationId || !messageId || !isSafeFileName(fileName)) {
    return null;
  }
  return { prefix, conversationId, messageId, fileName };
}

export function parseSendChatMessageInput(raw: unknown): ParsedSendInput {
  const data = (raw ?? {}) as Record<string, unknown>;
  for (const forbidden of ["senderId", "sentAt", "deleted", "participantIds"]) {
    if (data[forbidden] !== undefined) {
      throw new ChatInputError(
        "invalid-argument",
        `لا يمكن تمرير ${forbidden} من العميل`,
      );
    }
  }

  const conversationId = nonEmptyId(data.conversationId, "conversationId");
  const messageId = nonEmptyId(data.messageId, "messageId");
  if (!CHAT_MESSAGE_ID_PATTERN.test(messageId)) {
    throw new ChatInputError("invalid-argument", "messageId غير صالح");
  }

  const type = data.type === undefined ? "text" : data.type;
  if (!isChatMessageType(type)) {
    throw new ChatInputError("invalid-argument", "نوع الرسالة غير مدعوم");
  }

  const text = normalizeMessageText(data.text);

  if (type === "text") {
    if (text.length === 0) {
      throw new ChatInputError("invalid-argument", "لا يمكن إرسال رسالة فارغة");
    }
    if (data.media !== undefined && data.media !== null) {
      throw new ChatInputError("invalid-argument", "رسالة نصية لا تحمل ملفاً");
    }
    return { conversationId, messageId, type, text, media: null };
  }

  const media = (data.media ?? null) as Record<string, unknown> | null;
  if (!media || typeof media.storagePath !== "string") {
    throw new ChatInputError("invalid-argument", "مسار الملف مطلوب");
  }
  const storagePath = media.storagePath.trim();
  const parts = expectedMediaPathParts(storagePath);
  const policy = CHAT_MEDIA_POLICY[type];
  if (
    !parts
    || parts.prefix !== policy.prefix
    || parts.conversationId !== conversationId
    || parts.messageId !== messageId
  ) {
    throw new ChatInputError("invalid-argument", "مسار الملف لا يطابق الرسالة");
  }

  let fileName = parts.fileName;
  if (media.fileName !== undefined && media.fileName !== null) {
    if (typeof media.fileName !== "string" || !isSafeFileName(media.fileName.trim())) {
      throw new ChatInputError("invalid-argument", "اسم الملف غير صالح");
    }
    fileName = media.fileName.trim();
  }
  // The object name is persisted in media.storagePath, so it is checked even
  // when a separate display name is supplied.
  if (
    detectContactInfo(fileName) !== null
    || detectContactInfo(parts.fileName) !== null
  ) {
    throw new ChatInputError("invalid-argument", CONTACT_INFO_REJECTION_MESSAGE);
  }

  let durationMs: number | null = null;
  if (type === "voice") {
    const d = media.durationMs;
    if (
      typeof d !== "number"
      || !Number.isInteger(d)
      || d <= 0
      || d > CHAT_VOICE_MAX_DURATION_MS
    ) {
      throw new ChatInputError("invalid-argument", "مدة التسجيل غير صالحة");
    }
    durationMs = d;
  }

  return {
    conversationId,
    messageId,
    type,
    text,
    media: { storagePath, fileName, durationMs },
  };
}

export function signatureMatches(head: Uint8Array, sig: Signature[]): boolean {
  return sig.every(({ offset, bytes }) =>
    bytes.every((b, i) => head[offset + i] === b),
  );
}

/**
 * Validates a stored object against the media policy. Returns an Arabic
 * error message, or null when the object is acceptable.
 */
export function validateStoredMedia(params: {
  type: MediaType;
  callerUid: string;
  sizeBytes: number;
  contentType: string;
  uploaderId: string | undefined;
  head: Uint8Array;
}): string | null {
  const policy = CHAT_MEDIA_POLICY[params.type];
  if (params.uploaderId !== params.callerUid) {
    return "الملف لم يُرفع من حسابك";
  }
  if (!(params.sizeBytes > 0) || params.sizeBytes >= policy.maxBytes) {
    return "حجم الملف غير مسموح";
  }
  const contentType = params.contentType.split(";")[0].trim().toLowerCase();
  const signatures = policy.contentTypes[contentType];
  if (!signatures) {
    return "نوع الملف غير مسموح";
  }
  if (!signatures.some((sig) => signatureMatches(params.head, sig))) {
    return "محتوى الملف لا يطابق نوعه";
  }
  return null;
}

export function messagePreview(type: ChatMessageType, text: string): string {
  if (type === "text") {
    return text.length > CHAT_PREVIEW_MAX_CHARS
      ? `${text.slice(0, CHAT_PREVIEW_MAX_CHARS)}…`
      : text;
  }
  if (type === "image") return "صورة";
  if (type === "voice") return "رسالة صوتية";
  return "ملف";
}
