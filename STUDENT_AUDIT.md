# جرد واجهة الطالب (Student UI Audit)

تاريخ الجرد: 2026-07-19  
النطاق: صفحات/شاشات واجهة **الطالب فقط** تحت `lib/features/` (مع استبعاد أدوار المعلم / ولي الأمر /
المشرف / الأدمن كواجهات مستقلة).  
الأسلوب المستخدم في التنقل: **GoRouter** (`context.push`) غالباً؛ وبعض الشاشات الفرعية بـ
`Navigator.push(MaterialPageRoute)`.

---

## ملخص سريع

| التقييم                  | العدد (تقريبي)                                   |
|--------------------------|--------------------------------------------------|
| شغالة بالكامل            | 6                                                |
| ناقصة جزئياً             | 14                                               |
| هيكل فقط                 | 2                                                |
| متستخدمش / orphan للطالب | 3 (+ صفحة بروفايل تحت مجلد student لكنها للمعلم) |

---

## جدول كل صفحات الطالب

| #  | الصفحة (Class)               | المسار الكامل                                                                       | Feature                      | Route في GoRouter؟                                 | طريقة الوصول من الـ UI                                            | البيانات / Bloc                                                                       | TODO / نواقص                                                      | التقييم                                                           |
|----|------------------------------|-------------------------------------------------------------------------------------|------------------------------|----------------------------------------------------|-------------------------------------------------------------------|---------------------------------------------------------------------------------------|-------------------------------------------------------------------|-------------------------------------------------------------------|
| 1  | `StudentHomePage`            | `lib/features/student/presentation/pages/student_home_page.dart`                    | student                      | نعم — `/student`                                   | بعد تسجيل دخول دور طالب (redirect)                                | `StudentBloc` عام (Firestore: بروفايل، تقييمات، إنجازات، تكليف) + `NotificationsBloc` | TODO gamification / خطة حفظ / هدف أسبوع؛ بحث «قريباً»             | ناقصة جزئياً                                                      |
| 2  | `_StudentHomeTab` (الرئيسية) | نفس الملف أعلاه                                                                     | student                      | لا (IndexedStack tab 0)                            | تاب «الرئيسية» في Bottom Nav                                      | `BlocBuilder<StudentBloc>`                                                            | نفس TODOs الـ Home                                                | ناقصة جزئياً                                                      |
| 3  | `StudentMushafDashboard`     | `lib/features/student/presentation/pages/student_mushaf_dashboard.dart`             | student                      | لا (IndexedStack tab 1)                            | تاب «مصحفي» في Bottom Nav                                         | `StudentBloc` للتقدم؛ قائمة سور **hardcoded** جزئياً                                  | سور مقفولة / «قريباً»                                             | ناقصة جزئياً                                                      |
| 4  | `StudentBadgesPage`          | `lib/features/student/presentation/pages/student_badges_page.dart`                  | student                      | نعم — `/student/badges` **وأيضاً** tab             | تاب النجمة في Bottom Nav؛ ومن الإنجازات `AppRoutes.studentBadges` | `StudentBloc` (عملات/إنجازات) + قواعد شارات hardcoded                                 | —                                                                 | ناقصة جزئياً                                                      |
| 5  | `_StudentMapTab` (خريطتي)    | داخل `student_home_page.dart`                                                       | student                      | لا (IndexedStack tab 3)                            | تاب «خريطتي»                                                      | **لا Bloc** — UI ثابت (XP / مستويات وهمية)                                            | معلّق كـ placeholder لمرحلة لاحقة                                 | هيكل فقط                                                          |
| 6  | `_StudentProfileTab` (حسابي) | داخل `student_home_page.dart`                                                       | student                      | لا (IndexedStack tab 4)                            | تاب «حسابي»                                                       | `StudentBloc` (بروفايل حقيقي)                                                         | عناصر قائمة: حساب ولي أمر / مساعدة = «قريباً»                     | ناقصة جزئياً                                                      |
| 7  | `StudentEvaluationsPage`     | `lib/features/student/presentation/pages/student_evaluation_page.dart`              | student                      | نعم — `/student/evaluations`                       | Home: كارت «آخر تقييم» → `context.push('/student/evaluations')`   | `StudentBloc` / سجلات التلاوة من Firestore                                            | —                                                                 | شغالة بالكامل                                                     |
| 8  | `NotificationsPage`          | `lib/features/notifications/presentation/pages/notification_page.dart`              | notifications                | نعم — `/student/notifications`                     | أيقونة الإشعارات في هيدر الـ Home                                 | `NotificationsBloc` + Firestore                                                       | —                                                                 | شغالة بالكامل                                                     |
| 9  | `StudentSchedulePage` (حصصي) | `lib/features/schedule/presentation/pages/student_schedule_page.dart`               | schedule                     | نعم — `/student/schedule`                          | إجراءات سريعة «حصصي»؛ كارت الحصة؛ كارت بديل لو مفيش حلقة          | `ScheduleBloc` + usecases؛ datasource **mock**                                        | TODO ربط Firestore `classSessions`                                | ناقصة جزئياً                                                      |
| 10 | `StudentReviewSchedulePage`  | `lib/features/review_schedule/presentation/pages/student_review_schedule_page.dart` | review_schedule              | نعم — `/student/review-schedule`                   | إجراءات سريعة «جدول المراجعة»                                     | `ReviewScheduleBloc`؛ datasource **mock**                                             | TODO ربط `reviewSchedules`                                        | ناقصة جزئياً                                                      |
| 11 | `StudentHomeworkPage`        | `lib/features/homework/presentation/pages/student_homework_page.dart`               | homework                     | نعم — `/student/homework`                          | إجراءات سريعة «واجباتي»؛ كارت درس اليوم / زر اقرأ                 | `HomeworkBloc`؛ بيانات **`_mock` داخلية**                                             | TODO Firestore + إضافة نقاط للطالب                                | ناقصة جزئياً                                                      |
| 12 | `StudentProgressReportPage`  | `lib/features/progress_report/presentation/pages/student_progress_report_page.dart` | progress_report              | نعم — `/student/progress-report`                   | إجراءات سريعة؛ كارت تقدم الحفظ؛ حسابي → تقريري الشهري             | `ProgressReportBloc`؛ تقرير **mock** + دقة الحفظ من `overallProgressPercent` الحقيقي  | TODO analytics / حضور / ملاحظات                                   | ناقصة جزئياً                                                      |
| 13 | `StudentAchievementsPage`    | `lib/features/student/presentation/pages/student_achievements_page.dart`            | student                      | نعم — `/student/achievements`                      | هيدر (نجوم)؛ قائمة حسابي «شاراتي»                                 | `StudentBloc` + صفوف UI مخلوطة hardcoded                                              | —                                                                 | ناقصة جزئياً                                                      |
| 14 | `StudentStreakPage`          | `lib/features/student/presentation/pages/student_streak_page.dart`                  | student                      | نعم — `/student/streak`                            | هيدر (يوم متواصل)؛ من صفحة الإنجازات                              | `streakDays` من البروفايل؛ milestones hardcoded                                       | منطق حساب الاستريك لسه مش كامل (يُقرأ فقط)                        | ناقصة جزئياً                                                      |
| 15 | `StudentMushafPage`          | `lib/features/student/presentation/pages/student_mushaf_page.dart`                  | student                      | نعم — `/student/mushaf` (+ query: surah/mode/free) | من Dashboard المصحف؛ من كارت السورة الحالية في حسابي              | بدون Bloc صفحة؛ API قرآن + صوت؛ cache محلي                                            | «مشاركة السورة قريباً»؛ إرسال التسجيل للمعلم غير مربوط بـ Storage | شغالة بالكامل (القراءة/الاستماع)؛ ناقصة في المشاركة/الرفع السحابي |
| 16 | `StudentAudioLibraryPage`    | `lib/features/student/presentation/pages/student_audio_library_page.dart`           | student (+ audio_library)    | نعم — `/student/audio`                             | زر «استمع» في درس اليوم؛ من المصحف/الداشبورد                      | `AudioLibraryBloc` + usecases حقيقية (API/Firestore حسب التنفيذ)                      | رسالة فراغ: «سيتم إضافة التلاوات قريباً»                          | شغالة بالكامل                                                     |
| 17 | `AllRecitersPage`            | `lib/features/audio_library/presentation/pages/all_reciters_page.dart`              | audio_library                | **لا** (Navigator فقط)                             | من مكتبة الصوتيات → «عرض الكل»                                    | نفس `AudioLibraryBloc` (موروث)                                                        | —                                                                 | شغالة بالكامل                                                     |
| 18 | `StudentRecitationPage`      | `lib/features/student/presentation/pages/student_recitation_page.dart`              | student                      | **لا** (Navigator فقط)                             | من المصحف (وضع تسميع)؛ من واجب «تسميع»                            | تسجيل محلي + `SharedPreferences`؛ **بدون** رفع Firestore                              | إرسال وهمي/محلي؛ لا pipeline رفع صوتي للمعلم                      | ناقصة جزئياً                                                      |
| 19 | `AvatarSelectionPage`        | `lib/features/student/presentation/pages/avatar_selection_page.dart`                | student                      | نعم — `/student/avatar`                            | هيدر الأفاتار؛ حسابي → تغيير الشخصية                              | `StudentBloc` تحديث الأفاتار في Firestore                                             | —                                                                 | شغالة بالكامل                                                     |
| 20 | `SettingsPage`               | `lib/features/student/presentation/pages/settings_page.dart`                        | student                      | نعم — `/student/settings`                          | حسابي → إعدادات / أيقونة ترس                                      | بدون Bloc صفحة؛ `SharedPreferences` / تفضيلات                                         | لغات إضافية وبنود «قريباً»                                        | ناقصة جزئياً                                                      |
| 21 | `ContentLibraryPage`         | `lib/features/content/presentation/pages/content_library_page.dart`                 | content                      | نعم — `/student/content`                           | **لا يوجد زر/تاب من واجهة الطالب** (الرابط مسجّل فقط)             | `ContentLibraryBloc` + Firestore/Storage (التنفيذ جاهز)                               | —                                                                 | **متستخدمش خالص (orphan للطالب)** — التنفيذ نفسه مكتمل            |
| 22 | History (`_PlaceholderPage`) | معرّف داخل `lib/core/router/router_app.dart` (مش ملف feature)                       | router                       | نعم — `/student/history`                           | **لا يوجد دخول من الـ UI**                                        | لا بيانات — نص «السجل — قريباً»                                                       | Placeholder صريح                                                  | هيكل فقط + **orphan**                                             |
| 23 | `StudentProfilePage`         | `lib/features/student/presentation/pages/student_profile_page.dart`                 | student (ملف) / استخدام معلم | نعم لكن تحت **`/teacher/student/:studentId`**      | من واجهة المعلم فقط                                               | `TeacherBloc`                                                                         | إحصائيات جزئية hardcoded                                          | **ليست واجهة طالب ذاتية** (عرض معلم لملف طالب)                    |

---

## Bottom Navigation (مرجع)

داخل `StudentHomePage` — `IndexedStack`:

| Index | التسمية       | المحتوى                  |
|-------|---------------|--------------------------|
| 0     | الرئيسية      | `_StudentHomeTab`        |
| 1     | مصحفي         | `StudentMushafDashboard` |
| 2     | (نجمة مرتفعة) | `StudentBadgesPage`      |
| 3     | خريطتي        | `_StudentMapTab`         |
| 4     | حسابي         | `_StudentProfileTab`     |

---

## الصفحات اليتيمة (Orphan) — للطالب

صفحات/مسارات موجودة في الكود أو الـ Router **بدون أي زرار/تاب/كارت** يوصلها الطالب من الواجهة:

| العنصر        | المسار / الملف                            | الملاحظة                                                             |
|---------------|-------------------------------------------|----------------------------------------------------------------------|
| مكتبة المحتوى | `/student/content` → `ContentLibraryPage` | Route مسجّل؛ التنفيذ شغال؛ **مفيش `context.push` من UI الطالب**      |
| السجل         | `/student/history` → `_PlaceholderPage`   | Placeholder + **مفيش دخول من UI**                                    |
| الدردشة       | لا route طالب                             | `ChatRoom` / المحادثات للمعلم فقط؛ سياسة الصلاحيات لا تشمل `student` |

> ملاحظة: `StudentProfilePage` تحت مجلد `student` لكنها **مش orphan** — هي صفحة معلم (
`/teacher/student/:id`)، وليست بروفايل الطالب الذاتي (البروفايل الذاتي = تاب حسابي).

---

## ملاحظات معمارية سريعة

1. **حلقتي الأربع** (`schedule` / `homework` / `review_schedule` / `progress_report`): UI + BLoC +
   usecases موجودة، لكن الـ datasources ما زالت **mock** مع TODO واضح.
2. **درس اليوم** مربوط بـ `assignments` عبر `StudentBloc` (حقيقي)، بينما صفحة **واجباتي** لسه mock
   منفصل — ازدواجية مصدر محتملة لاحقاً.
3. شاشات فرعية بدون GoRouter (`AllRecitersPage`, `StudentRecitationPage`) شغّالة عبر `Navigator`؛
   متسقة مع باقي التطبيق لكنها أصعب في deep linking.
4. التقييمات / الإشعارات / الأفاتار / مكتبة الصوت / المصحف القرائي: أقرب للحالة «شغالة بالكامل» من
   ناحية تدفق الطالب الحالي.

---

## مصادر الجرد

- مسح `lib/features/**/presentation/pages/`
- `lib/core/router/router_app.dart` (Student routes)
- `student_home_page.dart` (Bottom Nav + pushes)
- datasources في `schedule` / `homework` / `review_schedule` / `progress_report`
