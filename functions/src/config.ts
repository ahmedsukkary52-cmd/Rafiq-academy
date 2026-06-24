import { defineSecret } from "firebase-functions/params";

/**
 * الأسرار دي بتتخزن في Google Cloud Secret Manager، مش في الكود ولا في
 * أي ملف بيتعمله git push. بتتحط مرة واحدة من الـ terminal:
 *
 *   firebase functions:secrets:set PAYMOB_SECRET_KEY
 *   firebase functions:secrets:set PAYMOB_HMAC_SECRET
 *   firebase functions:secrets:set PAYMOB_PUBLIC_KEY
 *   firebase functions:secrets:set PAYMOB_INTEGRATION_ID
 *
 * كل سر بيتاخد من Paymob Dashboard > Settings > Account Info / Payment
 * Integrations. الـ PUBLIC_KEY مش سري فعلياً (بيتبعت للموبايل أصلاً عشان
 * يبني رابط الدفع)، لكن بنحطه هنا كمان عشان لو اتغيّر، نغيّره من مكان
 * واحد بس من غير ما نعمل نشر تطبيق جديد.
 */
export const paymobSecretKey = defineSecret("PAYMOB_SECRET_KEY");
export const paymobHmacSecret = defineSecret("PAYMOB_HMAC_SECRET");
export const paymobPublicKey = defineSecret("PAYMOB_PUBLIC_KEY");
export const paymobIntegrationId = defineSecret("PAYMOB_INTEGRATION_ID");