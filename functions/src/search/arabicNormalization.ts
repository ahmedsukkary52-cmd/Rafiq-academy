/**
 * WA-14 / C13.2 — frozen Arabic search normalization.
 *
 * The exact step order below is the contract. `lib/shared/domain/
 * arabic_search_normalizer.dart` mirrors it, and both sides are pinned by the
 * shared vectors in [ARABIC_NORMALIZATION_VECTORS] so they cannot drift.
 *
 * `ؤ` (U+0624) and `ئ` (U+0626) are deliberately NOT folded — the frozen
 * contract keeps the existing project precedent, which unifies alef only.
 */

/** Bumped only when the steps below change; stored on every projection. */
export const ARABIC_NORMALIZATION_VERSION = 1;

/** Step 3 — tashkeel/harakat plus superscript alef. */
const TASHKEEL = /[\u064B-\u065F\u0670]/g;
/** Step 4 — tatweel (kashida). */
const TATWEEL = /\u0640/g;
/** Step 5 — أ إ آ ٱ → ا */
const ALEF_VARIANTS = /[\u0622\u0623\u0625\u0671]/g;
/** Step 6 — ى → ي */
const ALEF_MAQSURA = /\u0649/g;
/** Step 7 — ة → ه */
const TEH_MARBUTA = /\u0629/g;
/** Step 8 — collapse internal whitespace runs. */
const WHITESPACE_RUN = /\s+/g;

/**
 * Frozen nine-step normalization. Non-string input normalizes to `""` so a
 * malformed source document can never throw inside a background trigger.
 */
export function normalizeArabicSearchText(raw: unknown): string {
  if (typeof raw !== "string") return "";
  return raw
    .trim()
    .toLowerCase()
    .replace(TASHKEEL, "")
    .replace(TATWEEL, "")
    .replace(ALEF_VARIANTS, "\u0627")
    .replace(ALEF_MAQSURA, "\u064A")
    .replace(TEH_MARBUTA, "\u0647")
    .replace(WHITESPACE_RUN, " ")
    .trim();
}

/**
 * Cross-language contract vectors. The Dart helper is asserted against this
 * exact table in `test/security/wa14_student_search_contract_test.dart`.
 */
export const ARABIC_NORMALIZATION_VECTORS: ReadonlyArray<{
  readonly label: string;
  readonly input: string;
  readonly expected: string;
}> = [
  { label: "tashkeel", input: "مُحَمَّدٌ", expected: "محمد" },
  { label: "superscript alef", input: "رَحْمَٰن", expected: "رحمن" },
  { label: "alef hamza above", input: "أحمد", expected: "احمد" },
  { label: "alef hamza below", input: "إبراهيم", expected: "ابراهيم" },
  { label: "alef madda", input: "آمنة", expected: "امنه" },
  { label: "alef wasla", input: "ٱسماعيل", expected: "اسماعيل" },
  { label: "tatweel", input: "مـــحـمد", expected: "محمد" },
  { label: "alef maqsura", input: "يحيى", expected: "يحيي" },
  { label: "teh marbuta", input: "فاطمة", expected: "فاطمه" },
  { label: "whitespace collapse", input: "  محمد\t\tعلي  ", expected: "محمد علي" },
  { label: "latin lowercase", input: "Ahmed ALI", expected: "ahmed ali" },
  { label: "waw hamza preserved", input: "مؤمن", expected: "مؤمن" },
  { label: "yeh hamza preserved", input: "رئيس", expected: "رئيس" },
  { label: "empty", input: "", expected: "" },
  { label: "whitespace only", input: "   \t \n ", expected: "" },
  {
    label: "combined",
    input: "  أحـمَد   بنُ  عَلِيّة ",
    expected: "احمد بن عليه",
  },
];
