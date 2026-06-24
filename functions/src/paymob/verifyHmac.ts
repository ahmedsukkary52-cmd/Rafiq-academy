import * as crypto from "crypto";

/**
 * الترتيب الرسمي للحقول اللي Paymob بتستخدمه لحساب الـ HMAC في
 * "Transaction Processed Callback" (موثّق في Paymob Docs، مستقر منذ
 * سنين لكن تأكد منه في الـ Dashboard بتاعك وقت التفعيل الفعلي).
 *
 * بنحوّل كل قيمة لـ string، نلزقهم في الترتيب ده بالظبط (من غير فواصل)،
 * ونعمل HMAC-SHA512 بالـ secret، ونقارن الناتج (hex) بالـ hmac اللي
 * Paymob بعتته في الـ query parameter.
 */
const HMAC_FIELDS_ORDER = [
  "amount_cents",
  "created_at",
  "currency",
  "error_occured",
  "has_parent_transaction",
  "id",
  "integration_id",
  "is_3d_secure",
  "is_auth",
  "is_capture",
  "is_refunded",
  "is_standalone_payment",
  "is_voided",
  "order.id",
  "owner",
  "pending",
  "source_data.pan",
  "source_data.sub_type",
  "source_data.type",
  "success",
] as const;

/** بيجيب قيمة حقل، بما فيها الحقول المتداخلة زي "order.id" */
function getNestedValue(obj: Record<string, unknown>, path: string): unknown {
  return path
    .split(".")
    .reduce<unknown>(
      (acc, key) =>
        acc && typeof acc === "object"
          ? (acc as Record<string, unknown>)[key]
          : undefined,
      obj,
    );
}

/**
 * بيتأكد إن الـ webhook ده فعلاً جاي من Paymob مش حد بيحاول يزوّر طلب
 * "الدفع نجح" بإيده. لازم يتعمل التحقق ده قبل أي تحديث على Firestore.
 */
export function verifyPaymobHmac(
  transactionData: Record<string, unknown>,
  receivedHmac: string,
  hmacSecret: string,
): boolean {
  const concatenated = HMAC_FIELDS_ORDER.map((field) => {
    const value = getNestedValue(transactionData, field);
    return value === null || value === undefined ? "" : String(value);
  }).join("");

  const computedHmac = crypto
    .createHmac("sha512", hmacSecret)
    .update(concatenated)
    .digest("hex");

  // مقارنة "timing-safe" بدل === العادية، عشان نمنع هجوم بيقيس فرق
  // الوقت في المقارنة عشان يستنتج الـ HMAC الصح حرف بحرف.
  const computedBuffer = Buffer.from(computedHmac, "hex");
  const receivedBuffer = Buffer.from(receivedHmac, "hex");

  if (computedBuffer.length !== receivedBuffer.length) return false;
  return crypto.timingSafeEqual(computedBuffer, receivedBuffer);
}