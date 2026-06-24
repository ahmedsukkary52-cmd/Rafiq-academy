import * as admin from "firebase-admin";
import axios from "axios";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  paymobSecretKey,
  paymobPublicKey,
  paymobIntegrationId,
} from "../config";

interface CreateIntentionRequest {
  paymentId: string;
}

interface CreateIntentionResponse {
  clientSecret: string;
  publicKey: string;
}

/**
 * Callable Function - بتتنادى من التطبيق بـ paymentId بس (بدون مبلغ).
 *
 * نقاط الأمان المهمة هنا:
 * 1. التأكد إن المستخدم مسجّل دخول (request.auth).
 * 2. التأكد إن المستخدم ده فعلاً صاحب الدفعة (parentId == uid بتاعه)،
 *    مش أي حد مسجّل دخول يقدر يدفع نيابة عن حد تاني.
 * 3. المبلغ بيتقرأ من Firestore (مصدر موثوق فيه إحنا متحكمين)، مش من
 *    أي قيمة جاية من التطبيق - وإلا أي حد يقدر يعدّل الـ request
 *    ويدفع مبلغ أقل من المطلوب.
 */
export const createPaymentIntention = onCall<
  CreateIntentionRequest,
  Promise<CreateIntentionResponse>
>(
  {
    secrets: [paymobSecretKey, paymobPublicKey, paymobIntegrationId],
    region: "europe-west1",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
    }

    const { paymentId } = request.data;
    if (!paymentId || typeof paymentId !== "string") {
      throw new HttpsError("invalid-argument", "paymentId مطلوب");
    }

    const db = admin.firestore();
    const paymentRef = db.collection("payments").doc(paymentId);
    const paymentSnap = await paymentRef.get();

    if (!paymentSnap.exists) {
      throw new HttpsError("not-found", "لم يتم العثور على عملية الدفع");
    }

    const payment = paymentSnap.data()!;

    if (payment.parentId !== request.auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "غير مصرح لك بدفع هذا المستحق",
      );
    }

    if (payment.status === "paid") {
      throw new HttpsError(
        "failed-precondition",
        "تم سداد هذه الدفعة بالفعل",
      );
    }

    const amountCents = Math.round((payment.amount as number) * 100);

    const userSnap = await db.collection("users").doc(request.auth.uid).get();
    const userData = userSnap.data() ?? {};
    const fullName = (userData.name as string | undefined) ?? "ولي أمر";
    const [firstName, ...restName] = fullName.split(" ");

    // ⚠️ ملاحظة لأحمد: شكل الـ body بالظبط لـ Paymob Intention API
    // (الحقول المطلوبة/الاختيارية) لازم تتأكد منه من توثيق Paymob
    // الرسمي وقت التفعيل، الـ API ممكن يضيف/يغيّر حقول مع الوقت.
    let response;
    try {
      response = await axios.post(
        "https://accept.paymob.com/v1/intention/",
        {
          amount: amountCents,
          currency: "EGP",
          payment_methods: [Number(paymobIntegrationId.value())],
          items: [],
          billing_data: {
            apartment: "NA",
            first_name: firstName || "ولي",
            last_name: restName.join(" ") || "أمر",
            street: "NA",
            building: "NA",
            phone_number: (userData.phone as string | undefined) ?? "+201000000000",
            city: "NA",
            country: "EG",
            email: (userData.email as string | undefined) ?? "no-email@rafiq.app",
            floor: "NA",
            state: "NA",
          },
          // special_reference هو الرابط بين معاملة Paymob وdocument
          // الدفع عندنا - بيه بنطابق الـ webhook مع الدفعة الصح.
          special_reference: paymentId,
        },
        {
          headers: {
            Authorization: `Token ${paymobSecretKey.value()}`,
            "Content-Type": "application/json",
          },
          timeout: 15000,
        },
      );
    } catch (error) {
      console.error("Paymob intention request failed", error);
      throw new HttpsError(
        "internal",
        "تعذر بدء عملية الدفع، حاول مرة أخرى لاحقاً",
      );
    }

    const clientSecret = response.data?.client_secret as string | undefined;
    if (!clientSecret) {
      throw new HttpsError("internal", "استجابة غير متوقعة من بوابة الدفع");
    }

    return {
      clientSecret,
      publicKey: paymobPublicKey.value(),
    };
  },
);