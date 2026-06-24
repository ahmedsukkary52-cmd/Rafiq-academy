import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { paymobHmacSecret } from "../config";
import { verifyPaymobHmac } from "./verifyHmac";

/**
 * HTTPS Function عادية (مش Callable) لأن Paymob نفسها هي اللي بتنادي
 * الرابط ده مباشرة، مش التطبيق. لازم الرابط ده يتسجّل في Paymob
 * Dashboard > Integration Settings > Transaction Callback.
 *
 * الخطوات:
 * 1. تحقق من توقيع HMAC (هل الطلب فعلاً جاي من Paymob؟)
 * 2. لو الدفع نجح، حدّث document الدفعة في Firestore بـ status: paid
 * 3. الرد دايماً بـ 200 بسرعة (Paymob بتعيد المحاولة لو ماخدتش رد)،
 *    حتى في حالات زي "الدفعة مش موجودة" - عشان منضربش نفسنا بـ retries
 *    لا نهائية على حاجة مش هتتحل.
 */
export const paymobWebhook = onRequest(
  { secrets: [paymobHmacSecret], region: "europe-west1" },
  async (req, res) => {
    try {
      const receivedHmac = req.query.hmac as string | undefined;
      if (!receivedHmac) {
        res.status(400).send("Missing HMAC");
        return;
      }

      // Paymob بتلف بيانات المعاملة جوه حقل "obj" غالباً - بنتعامل مع
      // الحالتين احتياطاً.
      const body = req.body as Record<string, unknown>;
      const transaction = (body.obj ?? body) as Record<string, unknown>;

      const isValid = verifyPaymobHmac(
        transaction,
        receivedHmac,
        paymobHmacSecret.value(),
      );

      if (!isValid) {
        // ده أهم سطر أمان في الملف كله - لو فشل التحقق، منعملش أي
        // تحديث على Firestore مهما كان محتوى الطلب.
        console.warn("Paymob webhook: invalid HMAC signature - rejected");
        res.status(403).send("Invalid signature");
        return;
      }

      const success = transaction.success === true;
      const paymentId = transaction.special_reference as string | undefined;

      if (!success || !paymentId) {
        // مش بالضرورة خطأ - ممكن يكون إشعار "فشل دفع" عادي من Paymob.
        // بنرد 200 عشان ميعملش retry على حاجة مش محتاجة تحديث.
        res.status(200).send("Acknowledged (no update needed)");
        return;
      }

      const db = admin.firestore();
      const paymentRef = db.collection("payments").doc(paymentId);
      const paymentSnap = await paymentRef.get();

      if (!paymentSnap.exists) {
        console.error(`Paymob webhook: payment ${paymentId} not found`);
        res.status(200).send("Payment not found");
        return;
      }

      // Idempotency: لو الـ webhook اتبعت أكتر من مرة لنفس الدفعة
      // (Paymob بتعمل ده أحياناً)، متعملش تحديث تاني من غير داعي.
      if (paymentSnap.data()?.status === "paid") {
        res.status(200).send("Already processed");
        return;
      }

      await paymentRef.update({
        status: "paid",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        method: "paymob",
      });

      res.status(200).send("OK");
    } catch (error) {
      console.error("Paymob webhook error", error);
      res.status(500).send("Internal error");
    }
  },
);