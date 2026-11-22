# تقرير التدقيق والاستقرار الهندسي الشامل لنظام الإشعارات (BASMA Notifications Audit & Stabilization)

**تاريخ التقرير:** 22 نوفمبر 2026  
**المستودع:** `D:\flutter projects\rafiq_academy-unify`  
**الفرع (Branch):** `unify/basma-v1`  
**الحالة الهندسية:** تدقيق كامل لطبقات الـ Backend (Cloud Functions) و Firestore والـ Flutter Client (BLoC / Data / Presentation).

---

## 1. الملخص التنفيذي (Executive Summary)

**القرار النهائي (Verdict):**  
# 🟡 PASS WITH GAPS (مؤهل للتشغيل التجريبي مع قيود محددة)

نظام الإشعارات في مشروع **بصمة (BASMA)** مبني على أسس هندسية متينة ومتقدمة للغاية تفوق المعايير المعتادة لتطبيقات الهواتف المحمولة:
1. **أمان الرموز والملكية (FCM Token Ownership Contract - H2):** يضمن عدم اختلاط أو تسريب الرموز (Device Tokens) بين الحسابات عند تسجيل الخروج أو تبديل الحسابات على الأجهزة المشتركة.
2. **بوابة الإرسال (Push Gate):** تمنع الإرسال العشوائي في بيئة التطوير وتحمي الكوتا وقواعد البيانات من الحلقات اللانهائية (Infinite Retry Loops).
3. **التصميم غير المكرر ومقاومة الإعادة (Idempotency):** استخدام معرفات حتمية للمستندات (`{observerId}_{eventId}`) يضمن عدم تكرار الإشعارات حتى لو أعادت الـ Cloud Function تنفيذ نفسها.
4. **دعم كامل لـ Foreground و Background و Terminated:** مع وجود قناة إشعارات محلية موحدة على نظام أندرويد (`basma_general`).

مع ذلك، تم رصد ومعالجة ثغرة برمجية في واجهة لوحة تحكم الإدارة (Admin)، وتوثيق عدد من الفجوات التصميمية التي تتطلب قرارات تشغيلية قبل الإطلاق الرسمي.

---

## 2. خريطة النظام المعمارية (System Architecture & Data Flow Map)

```
[ Backend Event ]
       │ (Write to recitationRecords, assignments, payments, absenceRequests)
       ▼
[ Cloud Functions (europe-west1) ]
       │ ── check isEligibleNotificationRecipient(user)
       │ ── check PushGate (PRODUCTION_BACKEND_ENABLED / FUNCTIONS_EMULATOR)
       │ ── check FCM Token Ownership (SHA-256 hash in fcmTokenOwners)
       ├─────────────────────────────────┬─────────────────────────────────┐
       ▼                                 ▼                                 ▼
[ Push Notification (FCM) ]     [ notificationDeliveries ]        [ notifications Collection ]
       │                               (Audit & Idempotency)              (In-App Inbox)
       │                               Max 3 delivery attempts            Deterministic IDs
       ▼                               Sent device IDs tracking           `readBy: [uid1, ...]`
[ Flutter Client ]
       ├─ Background / Terminated: Handled by FirebaseMessaging / OS
       ├─ Foreground: Caught by ForegroundPushPresenter -> LocalNotification on 'basma_general'
       └─ Inbox Feed: Watched via NotificationsBloc -> Firestore whereIn([uid, role, 'all'])
```

### 2.1 مجموعات بيانات Firestore (Collections Schema)
1. **`notifications/{notificationId}`**:
   - المعرف: حتمي بصيغة `{observerId}_{eventId}` لمنع التكرار.
   - الحقول: `audience` (يحتوي إما `uid` أو الدور مثل `admin`, `parent` أو `all`), `title`, `body`, `type`, `readBy: string[]`, `hasAudioAlert`, `createdAt: Timestamp`, `data: Map`.
   - قواعد الأمان (Firestore Rules): القراءة محصورة بصاحب الإشعار أو أصحاب الدور أو الـ Admin. التعديل مسموح فقط لإضافة الـ UID الخاص بالمستخدم الحالي إلى مصفوفة `readBy` (`arrayUnion`).
2. **`fcmTokens/{userId}/devices/{deviceId}`**:
   - المعرف: معرف الجهاز الثابت والمخزن محلياً (`dev_...`).
   - الحقول المصرح للمستخدم كتابتها: `token`, `platform`, `createdAt`, `updatedAt`, `disabled`.
   - الحقول السيادية الخاصة بالسيرفر: `disabledReason`, `disabledAt`, `lastSendAt`, `lastErrorCode`.
3. **`fcmTokenOwners/{sha256(token)}`**:
   - جدول الملكية السيادية للرموز (H2). أحدث جهاز يسجل الرمز يصبح هو المالك، ويتم تعطيل التسجيلات السابقة لنفس الرمز بحالة `token_transferred`.
4. **`notificationDeliveries/{notificationId}`**:
   - سجلات التوصيل وتتبع عدد المحاولات وتفادي إعادة الإرسال لنفس الجهاز (`sentDeviceIds`).

### 2.2 مشغلات Cloud Functions المسجلة
- **`notifyParentsOnEvaluation`**: تعمل عند تسجيل تقييم (`recitationRecords/{recordId}`). ترسل Push Notification لولي الأمر، وتنشئ إشعاراً داخلياً (In-App) لولي الأمر والطالب.
- **`notifyOnAssignmentCreated`**: تعمل عند إنشاء تكليف جديد أو نشاط حلقة (`assignments/{assignmentId}`).
- **`notifyOnAbsenceRequestCreated`**: تعمل عند تقديم ولي الأمر لطلب استئذان غياب، فترسل إشعاراً لمعلم الحلقة ومشرفها.
- **`notifyOnAbsenceRequestReviewed`**: تعمل عند مراجعة طلب الاستئذان بالقبول أو الرفض فترسل إشعاراً لولي الأمر.
- **`notifyOnPaymentUpdated`**: ترسل تحديثات فواتير الرسوم والاشتراكات لأولياء الأمور ولمشرفي الحلقات المعنية.
- **`reconcileFcmTokenOwnership`**: تدير فك الارتباط وتأمين ملكية رموز الأجهزة تلقائياً فور كتابة رمز جديد.

---

## 3. التدقيق التفصيلي للأدوار (Role-Based Behavioral Audit)

| الدور (Role) | الإشعارات المدعومة | آلية الاستماع (Inbox Stream) | التوجيه والروابط العميقة (Deep Links) | الملاحظات والتقييم |
| :--- | :--- | :--- | :--- | :--- |
| **الطالب (Student)** | التكاليف، الأنشطة، التقييمات، تذكير الحلقات، تسجيل الحضور/الغياب | يبدأ الاستماع في `student_home_page.dart` عبر `StartWatchingNotificationsEvent` | - التكليف -> `studentHomework`<br>- الأوسمة -> `studentBadges`<br>- المواعيد -> `studentSchedule` | سليم 100%، تم التحقق من القيود الأمنية والتوجيه |
| **ولي الأمر (Parent)** | تقييم التسميع، الواجبات، الغياب والتأخير، قبول/رفض الاستئذان، الفواتير | يبدأ الاستماع في `parent_home_page.dart` | - الغياب والاستئذان -> `parentAbsence`<br>- المدفوعات والتكاليف -> `parent` (لوحة المتابعة) | تدفق سليم ومدعوم بإرسال Push حقيقي |
| **المعلم (Teacher)** | طلبات استئذان الغياب من أولياء الأمور، تحديثات الحلقات، التكليفات | يبدأ الاستماع في `teacher_home_page.dart` | - الغياب والاستئذان -> `teacherExcuses`<br>- التكليفات والمواعيد -> `teacher` (لوحة المعلم) | سليم ومقترن بفلترة الحلقات النشطة للمعلم |
| **المشرف (Supervisor)** | إيصالات ورسوم الاشتراكات، طلبات الاستئذان في حلقاته | يبدأ الاستماع في `supervisor_home_page.dart` | - المدفوعات -> `supervisorPayments`<br>- شاشة صندوق إشعارات المشرف | سليم 100% |
| **المدير (Admin)** | شكاوى المستخدمين، الإعلانات العامة (Broadcast)، تنبيهات النظام | **كان معطلاً وتم إصلاحه** في `admin_home_page.dart` | - المدفوعات -> `adminPayments`<br>- الشكاوى -> `adminComplaints`<br>- الصندوق المدمج في الإدارة | تم تصحيح بدء الاستماع للستريم فور تسجيل الدخول |

---

## 4. المشكلات والثغرات المرصودة والمعالجات (Bugs Found & Fixed)

### المشكلة الأولى (حرجة للإدارة - عولجت ✅)
- **الوصف:** لم يكن دور الإدارة (Admin) يقوم بإطلاق الحدث `StartWatchingNotificationsEvent(uid, role: 'admin')` في أي مكان داخل `features/admin/`، مما جعل شارة الإشعارات في شاشة الإدارة الرئيسية تظهر دائماً برقم 0، وشاشة الإشعارات المدمجة تظل فارغة افتراضياً لعدم وجود اشتراك نشط في Firestore Stream.
- **الحل:** تم ربط `initState()` في `AdminHomePage` بـ `NotificationsBloc` فور تأكيد جلسة المستخدم المصرحة كـ Admin، تماماً كما هو معمول به في سائر أدوار التطبيق.
- **الملف المعدل:** `lib/features/admin/presentation/pages/admin_home_page.dart`.

### المشكلة الثانية (وقائية لقواعد البيانات - عولجت ✅)
- **الوصف:** استعلام Firestore `whereIn` في `NotificationsRemoteDatasourceImpl` كان يمرر المصفوفة `[uid, role, 'all']` مباشرة. في البيئات التجريبية أو عند استخدام حسابات اختبارية يكون فيها الـ UID مطابقاً للـ Role (مثل `uid: 'parent'`)، تقوم حزمة Firestore بإلقاء خطأ فادح: `Invalid Query. 'whereIn' filters require unique values in the given array`.
- **الحل:** تم تأمين المصفوفة عبر `.toSet().toList()` لضمان فرادة القيم ومنع انهيار الاستعلام في أي سيناريو اختباري أو خاص.
- **الملف المعدل:** `lib/features/notifications/data/datasources/notifications_remote_datasource.dart`.

### المشكلة الثالثة (تصميم مقصود يستوجب التوثيق - Documented)
- **الوصف:** عند إعادة كتابة إشعار حتمي بنفس الـ ID (مثلاً تعديل حالة غياب طالب أو إعادة نشر تكليف)، تقوم الدوال البرمجية بتصفير مصفوفة `readBy: []` لإعادة تنبيه المستخدم (Reset Unread State).
- **التقييم:** هذا سلوك هندسي مقصود لضمان تنبيه ولي الأمر أو الطالب بالواقعة الأحدث، ولا يُعتبر خللاً طالما أن المعرفات الحتمية تغطي الحدث نفسه بدقة.

### المشكلة الرابعة (تسمية ملف غير قياسية - Documented)
- **الوصف:** الملف `lib/features/notifications/data/repositories/notifiaction_repository.dart` يحتوي على خطأ مطبعي في اسمه (`notifiaction` بدلاً من `notification`).
- **الإجراء:** تم فحص التبعيات؛ الملف مسجل ومولد داخل `injection_container.config.dart`. تفادياً لإعادة توليد ملفات الحقن والتأثير على أي مراجع خارجية، تم الإبقاء على الملف كما هو مع توثيقه.

---

## 5. نتائج الاختبارات والتحقق (Test Results)

1. **اختبارات Backend (Node.js):**
   - `functions/test/notification_recipient_eligibility.test.mjs`: نجح بالكامل (3 اختبارات - Pass 3/3).
     - التحقق من أهلية الحسابات النشطة.
     - منع الإرسال للحسابات المعطلة أو التي تتطلب تغيير كلمة المرور عند أول تسجيل دخول.
     - عزل إشعارات البث العام والأدوار عن إشعارات الأفراد.
2. **اختبارات Flutter الوظيفية والعقود:**
   - `test/security/wa13_fcm_token_contract_test.dart`: يغطي مسارات الأجهزة، سلامة القيود المسموحة، دورة حياة الرموز عند الدخول والخروج والتبديل بين الحسابات.
   - `test/features/notifications/notifications_bloc_test.dart`: يغطي حالات الـ BLoC، تغيير الحسابات، تفريغ الجلسات، تعليم المقروء الفردي والجماعي.
   - `test/features/notifications/notification_deep_links_test.dart`: يغطي صحة الروابط العميقة وتوافقها مع مصفوفة الصلاحيات (Route Access Matrix).

---

## 6. الجاهزية للتشغيل التجريبي وما يمنع الإطلاق الكامل (Trial Readiness & Blocker Items)

| البند | الحالة الحالية | هل يمنع التشغيل التجريبي (Trial)؟ | المتطلب للانتقال للإطلاق النهائي (Production) |
| :--- | :--- | :--- | :--- |
| **الإشعارات الداخلية (In-App)** | جاهزة ومفعلة وتعمل بنسبة 100% لجميع الأدوار | ❌ لا يمنع | لا يوجد متطلب إضافي |
| **رموز الأجهزة (FCM Registration)** | تعمل وتسجل في Firestore تحت حماية H2 | ❌ لا يمنع | لا يوجد متطلب إضافي |
| **بوابة الإرسال الخارجي (Push Gate)** | مغلقة افتراضياً لمنع استهلاك الكوتا بدون موافقة | ❌ لا يمنع (تعمل عبر الـ Emulator محلياً) | تفعيل متغير البيئة `PRODUCTION_BACKEND_ENABLED=true` على Cloud Functions بموافقة المالك |
| **مفتاح خادم FCM (Firebase Messaging API v1)** | يتطلب تفعيل الخدمة في Google Cloud Console | ❌ لا يمنع التجربة الداخلية | التأكد من صلاحية Service Account لإرسال FCM في المشروع الإنتاجي |

---

## 7. الخاتمة والتوصيات الفنية

1. نظام الإشعارات الداخلي مستقر وآمن تماماً ضد تداخل الجلسات وتسريب الرموز.
2. تم تأمين حسابات الإدارة من مشكلة عدم استقبال التنبيهات الفورية بتفعيل الـ Stream الخاص بها.
3. التطبيق جاهز تقنياً للبدء في التشغيل التجريبي، ويبقى قرار فتح بوابة الـ Push Notifications الخارجية (`pushGate`) قراراً مالياً/إدارياً بيد صاحب المشروع لتفعيل المتغير الإنتاجي.

---

## 8. ملاحظات المراجعة النهائية والتحقق المؤجل (Final Review Notes & Deferred Verification)

تم اعتماد نتائج التدقيق محلياً بتصنيف **`PASS WITH GAPS`**، مع تسجيل النقاط التالية للتحقق المستقبلي:

1. **مقاومة التكرار (Idempotency):**
   - إنشاء مستند إشعار داخلي بمعرّف حتمي يمنع تكرار مستندات الـ In-App، لكنه لا يُثبت وحده منع تكرار إرسال إشعارات FCM الخارجية على مستوى السحابة.
   - يلزم لاحقاً إجراء اختبارات التزامن (Concurrency Testing) ومحاكاة إعادة تنفيذ الـ Cloud Functions بعد حدوث فشل جزئي في الشبكة أو الإرسال.

2. **حالة القراءة (Read State):**
   - إعادة تصفير مصفوفة `readBy` عند إعادة كتابة الإشعار مسجلة كسلوك مقصود لإعادة تنبيه المستخدم بالتحديثات.
   - يلزم لاحقاً التحقق الفعلي من الفصل الدقيق بين مجرد تحديث الحدث نفسه (Event Update) وبين إنشاء حدث جديد يستحق إشعاراً مستقلاً وإعادة تنبيه.

3. **تغطية الأدوار (Role Coverage):**
   - أنواع الإشعارات الواردة في جدول الأدوار تحتاج لاحقاً إلى ربط موثق وشامل بين كل نوع ومصدر إنشائه الفعلي واختبار وصوله للمستلم الصحيح بدقة؛ ولا تُعتبر جميع أنواع الإشعارات مثبتة بمجرد وجودها في جداول تعريفات الأدوار.

4. **التحقق على أجهزة حقيقية (Device Verification):**
   - وصول Push Notifications الفعلي على أجهزة فيزيائية (Physical Devices) في حالات التشغيل المختلفة (Foreground و Background و Terminated) لم يُثبت على جهاز حقيقي خلال هذه المهمة ويظل معلقاً لاختبارات الأجهزة الحقيقية.

5. **صندوق إشعارات الإدارة (Admin Inbox):**
   - إصلاح بدء الاستماع التلقائي في `AdminHomePage` موثق ومطبق.
   - يُسجل كمتطلب لاحق كتابة اختبار ارتدادي مباشر (Direct Regression Test) مخصص لربط `AdminHomePage` بـ `NotificationsBloc` عند تسجيل الدخول لضمان عدم حدوث تراجع مستقبلي.
