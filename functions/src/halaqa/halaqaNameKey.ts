/**
 * Halaqa name uniqueness key.
 *
 * Two names are "the same halaqa" when their keys are equal:
 *   1. the frozen WA-14 Arabic normalization (tashkeel, tatweel, alef forms,
 *      ى→ي, ة→ه, lowercase, whitespace collapse);
 *   2. Eastern Arabic / Persian digits → ASCII digits;
 *   3. punctuation and symbols removed (so "حلقة-الفجر" == "حلقة الفجر").
 *
 * `lib/shared/domain/halaqa_name_key.dart` mirrors these steps for instant
 * form feedback; the server check below is the authority.
 */

import { normalizeArabicSearchText } from "../search/arabicNormalization";

export const HALAQA_NAME_INDEX_COLLECTION = "halaqaNameIndex";

const EASTERN_DIGITS = /[\u0660-\u0669\u06F0-\u06F9]/g;
const PUNCTUATION = /[\p{P}\p{S}]/gu;

export function halaqaNameKey(raw: unknown): string {
  const normalized = normalizeArabicSearchText(raw).replace(EASTERN_DIGITS, (d) => {
    const code = d.charCodeAt(0);
    return String(code >= 0x06f0 ? code - 0x06f0 : code - 0x0660);
  });
  return normalized.replace(PUNCTUATION, " ").replace(/\s+/g, " ").trim();
}

export const HALAQA_NAME_KEY_VECTORS: ReadonlyArray<{ input: string; expected: string }> = [
  { input: "حلقة الفجر", expected: "حلقه الفجر" },
  { input: "  حَلَقَةُ   الفَجْر ", expected: "حلقه الفجر" },
  { input: "حلقة-الفجر", expected: "حلقه الفجر" },
  { input: "حلقة الإمام", expected: "حلقه الامام" },
  { input: "حلقة ١", expected: "حلقه 1" },
  { input: "حلقة (أ)", expected: "حلقه ا" },
];
