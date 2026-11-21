# BASMA — Chat System End-to-End Audit & Remediation

**Date:** 2026-11-20 (updated same day — Attachment Emulator lifecycle)  
**Branch / HEAD:** `unify/basma-v1` @ `8ce64fe` (dirty working tree preserved; no git mutations, no deploy, no production Firebase changes)  
**Project used for Emulator evidence:** `demo-rafiq-rules` only  
**Verdict (chat system overall):** **PASS WITH GAPS**  
**Verdict (Attachment Emulator lifecycle — section below):** **PASS**

---

## A. حالة الشات قبل التعديل

### الملفات والمسارات المراجعة

| Layer | Paths |
|-------|--------|
| Presentation | `teacher_messages_tab.dart`, `supervisor_messages_tab.dart`, `parent_messages_tab.dart`, `student_chat_page.dart`, `admin_chat_inbox_page.dart`, `chat_room.dart`, `chat_composer.dart`, `chat_conversation_tile.dart`, `chat_message_bubble.dart`, `contact_student_parent.dart` |
| Domain | `chat_entities.dart`, `chat_permission_policy.dart`, `chat_media_policy.dart`, `chat_usecases.dart`, `ConversationIdGenerator` |
| Data | `chat_remote_datasource.dart`, `chat_repository_impl.dart`, Storage upload via `putFile` |
| Backend (read-only) | `createDirectConversation` / `sendChatMessage` callables, `firestore.rules` conversations/messages, `storage.rules` `chat_media` / `chat_voice` / `chat_attachments` |
| Links | `StudentParentLinkReader`, teacher/supervisor roster → parent IDs |

### المعمارية الفعلية

- Inbox per role → `ChatConversationsBloc` (GetIt singleton) watches conversations.
- Start 1:1 → `StartConversationEvent` → `createDirectConversation` callable (SSOT for relationships).
- Room → `ChatRoomBloc` + `sendChatMessage` / mark-read; media: pick → upload Storage → send with `storagePath`.
- UX policy (`ChatPermissionPolicy`) is a **pre-filter only**; server relationship graph is authoritative.

### ما كان يعمل

- فتح محادثات موجودة، إرسال نص، فقاعات، pagination أساسي للغرفة.
- Supervisor Plus: معلمون + أولياء أمور مرتبطون + أقران محادثات سابقة.
- `contactStudentParent` من ملف الطالب (ولي أمر واحد فقط عملياً).
- Storage rules تربط القراءة بعضوية المحادثة + مسار الرسالة (ليست مجرد معرفة الرابط).
- WA-11 contract tests: لا إرسال هوية مرسل من العميل؛ رفض الأزواج غير المسموحة محلياً.

### ما كان معطلاً / ناقص الإثبات

| Issue | Evidence |
|-------|----------|
| Teacher Plus بدون أولياء أمور وبدون بحث | `_NewChatPickerSheet` كان يجمع طلاب + مشرف فقط |
| Plus مع حلقات غير محمّلة → قائمة فارغة مضللة | يعتمد على `TeacherBloc.state.halaqat` دون انتظار تحميل |
| مرفقات: `path == null` يرمي ويستعرض «تعذر قراءة الملف» | `pickChatAttachment` بدون `withData` |
| متعدد أولياء الأمور يأخذ `parentIds.first` فقط | `contact_student_parent.dart` |
| قائمة أشخاص مرتبطة بالحلقات للمعلم | غير موجودة كمسار مكتمل |
| رفع مرفقات على جهاز حقيقي / Emulator E2E | غير مثبت |

---

## B. المشاكل المكتشفة

### Critical
- لا شيء يمنع تشغيل Production أو يسرّب صلاحيات كتابة من العميل بعد المراجعة.

### High
1. **Teacher Plus roster gap** — أولياء الأمور غير مدرجين رغم أن السياسة والسرفر يسمحان بعلاقة معلم↔ولي أمر عبر الطالب.
2. **Attachment path-null** — فشل اختيار الملف على منصات بدون `PlatformFile.path`.

### Medium
3. **Multi-parent silence** — التواصل مع ولي الأمر الأول فقط دون اختيار.
4. **Empty halaqat race** — فتح Plus قبل اكتمال تحميل الحلقات يعطي empty خاطئ.
5. **Supervisor/Teacher picker بدون بحث محلي** — UX ضعيف للقوائم الطويلة.

### Low
6. Inbox empty-state لأولياء الأمور كان يوجّه فقط لملف الطالب دون ذكر زر +.
7. `ChatConversationTile` بدون صورة شبكة للطرف الآخر / تمييز خفيف للغير مقروء.

### UX Improvement
8. قائمة أشخاص مرتبطة بالحلقات داخل تجربة الشات (معلم/مشرف) مع تسمية العلاقة.
9. تحسين copy وsearch داخل أوراق «محادثة جديدة».

### Product / schema gaps (موثّقة — بلا اختراع Schema)
- **Admin Plus discovery** لأكاديمية كاملة غير ممثلة كدليل علاقات؛ لا directory عام آمن مفترض — يحتاج قرار منتج.
- **Parent/Student related-people** لم تُعاد هندستها في هذه المهمة (مساراتهم الحالية مختلفة).
- لا يوجد إصدار عضوية (`membershipVersion`) لكاش roster طويل الأمد.

---

## C. الإصلاحات

| # | المشكلة | السبب الجذري | الملفات | الحل | الاختبار |
|---|---------|--------------|---------|------|----------|
| 1 | Teacher Plus بدون آباء/بحث | قائمة UID يدوية ناقصة | `teacher_chat_contacts.dart`, `teacher_messages_tab.dart` | `loadTeacherChatContacts` (طلاب + آباء عبر `StudentParentLinkReader` + مشرف) + بحث محلي + انتظار تحميل الحلقات | `teacher_chat_contacts_test.dart`, `teacher_messages_tab_test.dart` |
| 2 | Attachment path null | الاعتماد على path فقط | `chat_picked_file.dart`, `chat_composer.dart` | `withData: true` + كتابة temp من bytes | `chat_picked_file_test.dart`, `chat_room_page_test` (upload progress) |
| 3 | Multi-parent | `parentIds.first` | `contact_student_parent.dart` | Sheet «اختر ولي الأمر» عند >1 | `contact_student_parent_test` multi-parent |
| 4 | Supervisor search | لا فلتر نصي | `supervisor_messages_tab.dart` | `AppSearchField` + فلتر محلي | يغطي منطق مشابه في teacher contacts filter test |
| 5 | Inbox / tile UX | copy وavatar | `teacher_messages_tab.dart`, `chat_conversation_tile.dart` | copy محدّث؛ تمييز unread؛ صورة الطرف | tab + group inbox tests |

---

## D. الأداء

### ما اكتُشف
- فتح ورقة Plus يعيد جلب المشاركين في كل فتحة (مقبول لحجم حلقة؛ ليس inbox stream).
- بدون حلقات: **لا** استدعاء لـ parent links (تجنّب reads فارغة).
- Parent links تُطلب دفعة واحدة بـ `getParentIdsByStudentIds` ثم `Future.wait` للمشاركين.
- Inbox: `ChatConversationsBloc` singleton + `pageSize` افتراضي موجود مسبقاً.
- Room: رسائل newest-first مع pagination موجودة مسبقاً.

### تحسينات منفّذة
- تخطي parent reads عند عدم وجود طلاب.
- تحميل الحلقات قبل الورقة عند الحاجة (تجنّب empty كاذب وإعادة فتح متكررة).
- بحث محلي بعد التحميل (بدون reads إضافية).

### مؤجّل (بلا دليل إجباري لكاش دائم)
- كاش roster عبر الجلسة مع إبطال عند تغيّر عضوية الحلقة — يحتاج مصدر version صريح من الـ backend.
- لا إضافة كاش كمصدر حقيقة بديل.

---

## E. الأمن

### ما تم التحقق منه (قراءة قواعد + عقود اختبار)
- `createDirectConversation` / رفض الأزواج: `wa11_chat_authorization_contract_test.dart`.
- Storage: `canReadChatObject` يتطلب مشاركة المحادثة + رسالة غير محذوفة + `media.storagePath` مطابق؛ الرفع يتطلب مشاركة + `uploaderId` + عدم وجود رسالة مسبقاً.
- UI roster **ليس** حارس أمن؛ السرفر يبقى SSOT.

### حالات الرفض
- دور غير staff في `contactStudentParent`.
- إنكار علاقة من السرفر عند بدء المحادثة (موجود مسبقاً).
- سياسة المعلم لا تُظهر أدواراً خارج `ChatPermissionPolicy` في القائمة.

### مخاطر مفتوحة
- لم يُشغَّل suite قواعد Storage/Firestore الكامل في هذه الجولة (شُغّل فلتر Chat storage + lifecycle).
- تنظيف orphan على Emulator **مثبت**؛ على جهاز حقيقي ما زال **NOT TESTED**.

---

## F. نتائج الاختبارات

**أمر:**

```text
flutter test \
  test/features/teacher/teacher_chat_contacts_test.dart \
  test/features/chat/chat_picked_file_test.dart \
  test/features/staff/contact_parent/contact_student_parent_test.dart \
  test/features/teacher/teacher_messages_tab_test.dart \
  test/features/teacher/teacher_messages_group_inbox_test.dart \
  test/features/chat/chat_permission_policy_test.dart \
  test/features/chat/chat_media_policy_test.dart \
  test/security/wa11_chat_authorization_contract_test.dart \
  test/features/chat/chat_room_page_test.dart \
  test/features/chat/get_or_create_conversation_usecase_test.dart
```

**النتيجة:** **60/60 passed**, 0 failed, 0 skipped.

اختبارات جديدة/محدّثة تغطي: roster المعلم، بحث/فلترة، path-null attachments، multi-parent picker، empty-state أولياء الأمور.

---

## G. ما لم يتم التحقق منه

| Item | Status |
|------|--------|
| جهاز حقيقي (Android/iOS permissions + picker) | **NOT TESTED** |
| Flutter ↔ Emulator E2E للشات | **BLOCKED** — لا bootstrap آمن (`INTEGRATION_TEST_PREREQUISITES`) |
| رفع ملف فعلي إلى Emulator Storage ثم send + peer download | **CLOSED** — انظر قسم Attachment أدناه (**6/6** lifecycle + **12/12** Chat storage rules) |
| Admin related-people directory | **فجوة منتج** — بلا Schema جديد |
| Parent/Student Plus roster redesign | خارج نطاق الإصلاح الوظيفي الأساسي لهذه الجولة |
| Deploy / seed / production | **محظور عمداً** |

---

## H. القرار النهائي

### Chat system overall: **PASS WITH GAPS**

الشات متماسك وظيفياً على مسار المعلم/المشرف الأساسي بعد الإصلاحات: Plus → أشخاص مرتبطون بالحلقات → بدء محادثة عبر callable، ومسار المرفقات لم يعد ينكسر عند غياب `path`. الأمن ما زال مفروضاً من Backend وليس من إخفاء الواجهة.

دورة المرفقات على **Emulator** أصبحت مثبتة بأدلة (قسم Attachment). ما يبقى ناقصاً للجهاز الحقيقي وFlutter↔Emulator UI E2E وdirectory الإدارة — لذلك الحكم الإجمالي يبقى **PASS WITH GAPS**.

---

## Attachment End-to-End Emulator Verification

**Scope:** Firebase Emulator only (`demo-rafiq-rules`). No Production, no Deploy, no Seed.  
**Section verdict:** **PASS**

### الاختبارات المنفذة والنتائج

| Suite | Command | Result |
|-------|---------|--------|
| Attachment lifecycle (client Storage + callable) | `npx firebase emulators:exec --project demo-rafiq-rules --only auth,firestore,functions,storage "node --test --test-concurrency=1 rules_test/chat_attachment_lifecycle.emulator.test.mjs"` | **6/6 pass** |
| Chat Storage rules (name filter) | `npx firebase emulators:exec --project demo-rafiq-rules --only firestore,storage -- 'node --test --test-concurrency=1 --test-name-pattern=Chat.storage rules_test/storage.rules.test.mjs'` | **12/12 pass** |
| Flutter local path/bytes + outbox orphan behaviour | `flutter test test/features/chat/chat_picked_file_test.dart` + focused `chat_room_bloc_test` (cancel/retry/unsupported) | **3 + 8 pass** |

File: `rules_test/chat_attachment_lifecycle.emulator.test.mjs` (new).

### نوع الملفات المختبرة
- **JPEG** (`chat_media/...`) — مسار الصورة الأساسي.
- **PDF** (`chat_attachments/...`) — مسار الملف؛ رفض إرسال PDF كـ `type: image`.

### نتائج رفع Storage
- رفع عبر **Firebase JS client** المصادَق (Auth Emulator) يخضع لـ `storage.rules` (ليس admin SDK bypass).
- رفض `uploaderId` منتحل (معلم يرفع بـ metadata طالب).
- رفض غير العضو / الغريب / معرفة `conversationId` وحدها (ضمن قواعد Chat storage).

### نتائج حفظ واستقبال الرسائل
- بعد الرفع: `sendChatMessage` ينشئ الرسالة مع `media.storagePath` / `contentType` / `sizeBytes` / `fileName`.
- الطرف الآخر يقرأ وثيقة الرسالة من Firestore (عبر تحقق admin للقراءة بعد الإرسال؛ ACL العضوية مفروضة على Storage للتحميل).
- إعادة الإرسال بنفس `messageId` بعد النجاح: **idempotent** (`created: false`، رسالة واحدة).

### نتائج الوصول من الطرف الآخر
- قبل الإرسال: الطرف الآخر **لا** يقرأ اليتيم.
- بعد الإرسال: الطرف الآخر يحمّل البايتات وتطابق JPEG/PDF.
- ولي أمر / معلم غريب: **رفض** التحميل بمعرفة المسار فقط.

### نتائج اختبارات رفض الصلاحيات
- Spoofed `uploaderId` → رفض الرفع.
- `PERMISSION_DENIED` عند محاولة إرسال من غير عضو بعد رفع يتيم.
- رسالة محذوفة soft-delete: المشاركون لا يقرأون الوسائط؛ الكائن يبقى للتعديل الإداري (D20).
- قواعد Chat storage الإضافية: مسار غير مطابق، حجم زائد، نوع غير مسموح، لا overwrite، لا رفع على messageId مرسل مسبقاً.

### نتائج حالات الفشل وإعادة المحاولة
- رفع ثم فشل الإرسال (غير عضو) → لا رسالة؛ الرفع يتيم؛ المرفوع يحذف عبر `canDeleteOrphanChatObject`؛ مسار جديد ينجح.
- Flutter bloc: إلغاء أثناء الرفع يتجاهل اليتيم ولا يرسل؛ فشل الرفع ثم retry يحذف الجزئي ويعيد الرفع؛ فشل الإرسال بعد رفع ناجح يعيد الإرسال دون رفع مكرر.

### نتائج تنظيف الملفات المؤقتة واليتيمة
- **محلي (Flutter):** `resolveChatPickedLocalPath` يكتب temp عند غياب path؛ تنظيف temp على مستوى OS بعد الاستخدام ليس مسار Storage (موثّق كحد وحدة).
- **Storage orphan:** حذف المرفوع بواسطة الـ uploader قبل وجود رسالة — **مثبت** على Emulator.
- **بعد إرسال ناجح:** لا حذف orphan من العميل — **مثبت** (الرفض متوقع).
- soft-delete لا يحذف كائن Storage (سياسة الاحتفاظ) — **مثبت**.

### إصلاحات منتج في هذه الجولة
- **لا عيب منتج مؤكد** في مسار الرفع/الإرسال/القواعد.
- محاولة أولى بـ Storage REST multipart فشلت بـ 403؛ السبب أداة الاختبار لا القواعد. تم استبدالها بعميل Firebase JS (نفس مسار التطبيق المنطقي) — **لا تغيير على `storage.rules` أو Functions**.

### ما لم يتم التحقق منه (Attachment)
| Item | Status |
|------|--------|
| جهاز حقيقي (صلاحيات المعرض/الملفات + picker UI) | **NOT TESTED** |
| Flutter ↔ Emulator `integration_test` من زر المرفق في الشاشة | **BLOCKED** — لا bootstrap آمن |
| path vs bytes داخل Emulator (بعد resolve يصبح `putFile` على path محلي) | مثبت **وحدة** فقط (`chat_picked_file_test`) — كافٍ لأن Emulator يرى الملف بعد التعيين |
| تشغيل كامل لـ `chat_message_callable.emulator.test.mjs` مجدداً | غير معاد بالكامل؛ lifecycle الجديد يغطي السلسلة المطلوبة صراحة |

---

## ملحق — ملفات أُضيفت/عُدّلت

### جولة الشات السابقة
**Added:** `teacher_chat_contacts.dart`, `chat_picked_file.dart`, اختبارات مرتبطة، هذا التقرير.  
**Modified:** teacher/supervisor messages, composer, conversation tile, contact_student_parent.

### جولة Attachment Emulator
**Added:** `rules_test/chat_attachment_lifecycle.emulator.test.mjs`  
**Modified:** هذا التقرير فقط (لا تغيير قواعد/Functions للمنتج).
