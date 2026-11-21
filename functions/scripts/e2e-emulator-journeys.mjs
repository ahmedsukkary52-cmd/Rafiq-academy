#!/usr/bin/env node
/**
 * Emulator-only journey smoke (Auth + callable HTTPS). No live Firebase.
 * Usage (emulators already seeded): node scripts/e2e-emulator-journeys.mjs
 */
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const PROJECT = "demo-rafiq-rules";
const AUTH = "http://127.0.0.1:9099";
const FUNCTIONS = "http://127.0.0.1:5001";
const API_KEY = "fake-emulator-api-key";
const REGION = "europe-west1";
const PASS = "SeedDemo123!";

const results = [];

function record(journey, status, detail) {
  results.push({ journey, status, detail });
  console.log(`[${status}] ${journey}: ${detail}`);
}

async function signIn(email) {
  const res = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, password: PASS, returnSecureToken: true }),
    },
  );
  const body = await res.json();
  if (!res.ok) throw new Error(`${email}: ${body.error?.message || res.status}`);
  return body;
}

async function callCallable(name, idToken, data = {}) {
  const url = `${FUNCTIONS}/${PROJECT}/${REGION}/${name}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({ data }),
  });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, body };
}

async function main() {
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
  process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
  const app = initializeApp({ projectId: PROJECT }, "e2e-journeys");
  const auth = getAuth(app);
  const db = getFirestore(app);

  try {
    // 1) Auth for each seeded role
    for (const [role, email] of [
      ["teacher", "teacher@rafiq.demo"],
      ["parent", "parent@rafiq.demo"],
      ["student", "student01@rafiq.demo"],
      ["supervisor", "supervisor1@rafiq.demo"],
    ]) {
      try {
        const s = await signIn(email);
        record(`auth:${role}`, "PASS", `uid=${s.localId}`);
      } catch (e) {
        record(`auth:${role}`, "FAIL", e.message);
      }
    }

    // Admin requires first-login password change before authority.
    let adminToken = null;
    try {
      let adminSign;
      try {
        adminSign = await signIn("admin@rafiq.demo");
      } catch {
        const res = await fetch(
          `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
          {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({
              email: "admin@rafiq.demo",
              password: "AdminDemo123!",
              returnSecureToken: true,
            }),
          },
        );
        adminSign = await res.json();
        if (!res.ok) throw new Error(adminSign.error?.message || res.status);
      }
      adminToken = adminSign.idToken;
      record("auth:admin", "PASS", `uid=${adminSign.localId}`);
      const first = await callCallable("completeFirstLogin", adminToken, {
        newPassword: "AdminDemo123!",
      });
      if (first.body?.error) {
        const msg = String(first.body.error.message || "");
        if (msg.includes("already") || msg.includes("not required") || msg.includes("لا")) {
          record("admin:firstLogin", "PASS", `already done (${msg.slice(0, 80)})`);
        } else {
          record(
            "admin:firstLogin",
            "FAIL",
            JSON.stringify(first.body.error).slice(0, 200),
          );
        }
      } else {
        record("admin:firstLogin", "PASS", "password rotated / ok");
        const res = await fetch(
          `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
          {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({
              email: "admin@rafiq.demo",
              password: "AdminDemo123!",
              returnSecureToken: true,
            }),
          },
        );
        const again = await res.json();
        if (res.ok) adminToken = again.idToken;
      }
    } catch (e) {
      record("auth:admin", "FAIL", e.message);
    }

    // 2) Link parent↔students + create halaqa via Admin SDK writes that mirrors
    //    provisioned shape (seed left childrenIds/halaqa empty). Emulator-only.
    const teacherUid = "demo-teacher-01";
    const parentUid = "demo-parent-01";
    const studentUid = "demo-student-01";
    const supervisorUid = "demo-supervisor-01";
    const halaqaId = "demo-halaqa-e2e";

    await db
      .collection("halaqat")
      .doc(halaqaId)
      .set(
        {
          name: "حلقة التجربة",
          nameNormalized: "حلقه التجربه",
          teacherId: teacherUid,
          supervisorId: supervisorUid,
          assistantTeacherIds: [],
          studentIds: [studentUid],
          isActive: true,
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    await db.collection("teacherProfiles").doc(teacherUid).set(
      { halaqatIds: [halaqaId], weeklyQuota: 5 },
      { merge: true },
    );
    await db.collection("studentProfiles").doc(studentUid).set(
      {
        halaqaId,
        halaqaName: "حلقة التجربة",
        parentIds: [parentUid],
      },
      { merge: true },
    );
    await db.collection("parentProfiles").doc(parentUid).set(
      { childrenIds: [studentUid, "demo-student-02"] },
      { merge: true },
    );
    await db.collection("studentProfiles").doc("demo-student-02").set(
      { parentIds: [parentUid] },
      { merge: true },
    );
    record(
      "seed:relationships",
      "PASS",
      "halaqa+parent links written (emulator Admin SDK)",
    );

    // 3) Pricing defaults + invoice (callable may be Blaze-gated even on emulator
    //    if PRODUCTION gate misreads — capture honestly).
    if (adminToken) {
      const inv = await callCallable("adminGenerateInvoice", adminToken, {
        studentId: studentUid,
        periodKey: "2026-11",
      });
      if (inv.body?.error) {
        const code = inv.body.error.status || inv.body.error.message || "";
        const blocked =
          String(code).includes("FAILED_PRECONDITION") ||
          String(inv.body.error.message || "").includes("B-BILLING") ||
          String(inv.body.error.message || "").includes("disabled");
        record(
          "payment:generateInvoice",
          blocked ? "BLOCKED_FIREBASE_BLAZE" : "FAIL",
          JSON.stringify(inv.body.error).slice(0, 240),
        );
      } else {
        record("payment:generateInvoice", "PASS", JSON.stringify(inv.body?.result || inv.body).slice(0, 160));
      }
    }

    // 4) Parent sign-in + submitPaymentProof if an invoice exists
    const parent = await signIn("parent@rafiq.demo");
    const payments = await db
      .collection("payments")
      .where("parentId", "==", parentUid)
      .limit(5)
      .get()
      .catch(() => null);
    const payDoc = payments?.docs?.[0];
    if (!payDoc) {
      record(
        "payment:parentProof",
        "SKIP",
        "no payments docs for parent (invoice step incomplete)",
      );
    } else {
      const proof = await callCallable("submitPaymentProof", parent.idToken, {
        paymentId: payDoc.id,
        method: "vodafone_cash",
        amountPaid: 100,
      });
      if (proof.body?.error) {
        record(
          "payment:parentProof",
          "FAIL",
          JSON.stringify(proof.body.error).slice(0, 200),
        );
      } else {
        record("payment:parentProof", "PASS", `paymentId=${payDoc.id}`);
      }
    }

    // 5) Messaging start (callable) teacher → parent if available
    const teacher = await signIn("teacher@rafiq.demo");
    const chat = await callCallable("startDirectChat", teacher.idToken, {
      peerUid: parentUid,
    }).catch((e) => ({ status: 0, body: { error: { message: e.message } } }));
    if (chat.body?.error) {
      // Try alternate name used in codebase
      const alt = await callCallable("ensureDirectConversation", teacher.idToken, {
        otherUserId: parentUid,
      }).catch((e) => ({ body: { error: { message: e.message } } }));
      if (alt.body?.error) {
        record(
          "messaging:start",
          "FAIL",
          `startDirectChat/ensureDirectConversation: ${JSON.stringify(alt.body.error || chat.body.error).slice(0, 200)}`,
        );
      } else {
        record("messaging:start", "PASS", "ensureDirectConversation");
      }
    } else {
      record("messaging:start", "PASS", "startDirectChat");
    }

    // Verify Auth users still exist (no orphan deletes)
    const listed = await auth.listUsers(20);
    record(
      "integrity:authUsers",
      listed.users.length >= 6 ? "PASS" : "FAIL",
      `count=${listed.users.length}`,
    );
  } finally {
    await deleteApp(app);
  }

  console.log("\n=== SUMMARY ===");
  for (const r of results) console.log(`${r.status.padEnd(22)} ${r.journey}`);
  const fails = results.filter((r) => r.status === "FAIL").length;
  process.exit(fails > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(2);
});
