/// Demo Academy permanent development dataset — called from [seed_firestore.dart].
///
/// Idempotent: fixed document IDs under `demo_*` / stable Auth emails.
/// Safe to re-run; overwrites the same docs.
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/admin/domain/admin_ops_broadcast.dart';
import 'package:rafiq_academy/features/auth/data/models/user_model.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';
import 'package:rafiq_academy/features/student/data/models/assignment_model.dart';
import 'package:rafiq_academy/features/student/data/models/halaqa_schedule_model.dart';
import 'package:rafiq_academy/features/student/data/models/recitation_record_model.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/data/models/attendance_record_model.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/shared/data/achievements_firestore_contract.dart';
import 'package:rafiq_academy/shared/utils/absence_request_ids.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

// ── Stable IDs ───────────────────────────────────────────────────────────────

const demoAcademyId = 'demo_academy_rafiq';
const demoHalaqaMorningId = 'demo_halaqa_morning';
const demoHalaqaAfternoonId = 'demo_halaqa_afternoon';
const demoHalaqaEveningId = 'demo_halaqa_evening';

const demoPasswordDefault = 'SeedDemo123!';

/// Printed after seed — every Auth account in the dataset.
class DemoAccount {
  final String email;
  final String role;
  final String name;
  final String note;

  const DemoAccount({
    required this.email,
    required this.role,
    required this.name,
    this.note = '',
  });
}

const demoAccountsCatalog = <DemoAccount>[
  DemoAccount(
    email: 'admin@rafiq.demo',
    role: AppRoles.admin,
    name: 'خالد عبدالرحمن',
    note: 'مدير الأكاديمية',
  ),
  DemoAccount(
    email: 'supervisor1@rafiq.demo',
    role: AppRoles.supervisor,
    name: 'فهد السبيعي',
    note: 'مشرف الصباح والمساء',
  ),
  DemoAccount(
    email: 'supervisor2@rafiq.demo',
    role: AppRoles.supervisor,
    name: 'نورة القحطاني',
    note: 'مشرفة العصر',
  ),
  DemoAccount(
    email: 'teacher@rafiq.demo',
    role: AppRoles.teacher,
    name: 'عبدالله الحربي',
    note: 'معلم حلقتي الصباح والعصر (حساب Teacher Home الرئيسي)',
  ),
  DemoAccount(
    email: 'teacher2@rafiq.demo',
    role: AppRoles.teacher,
    name: 'سارة العتيبي',
    note: 'معلمة حلقة المساء',
  ),
  DemoAccount(
    email: 'teacher3@rafiq.demo',
    role: AppRoles.teacher,
    name: 'يوسف الدوسري',
    note: 'معلم مساند / احتياطي',
  ),
  DemoAccount(
    email: 'parent@rafiq.demo',
    role: AppRoles.parent,
    name: 'محمد العتيبي',
    note: 'ولي أمر بطفلين (أحمد + سارة)',
  ),
  DemoAccount(
    email: 'parent02@rafiq.demo',
    role: AppRoles.parent,
    name: 'سعود الشمري',
  ),
  DemoAccount(
    email: 'parent03@rafiq.demo',
    role: AppRoles.parent,
    name: 'هدى الغامدي',
  ),
  DemoAccount(
    email: 'parent04@rafiq.demo',
    role: AppRoles.parent,
    name: 'بندر المطيري',
  ),
  DemoAccount(
    email: 'parent05@rafiq.demo',
    role: AppRoles.parent,
    name: 'منال الزهراني',
  ),
  DemoAccount(
    email: 'parent06@rafiq.demo',
    role: AppRoles.parent,
    name: 'راشد العنزي',
  ),
  DemoAccount(
    email: 'parent07@rafiq.demo',
    role: AppRoles.parent,
    name: 'لينا الحربي',
  ),
  DemoAccount(
    email: 'parent08@rafiq.demo',
    role: AppRoles.parent,
    name: 'طلال الشهري',
  ),
  DemoAccount(
    email: 'parent09@rafiq.demo',
    role: AppRoles.parent,
    name: 'أمل الجهني',
  ),
  DemoAccount(
    email: 'parent10@rafiq.demo',
    role: AppRoles.parent,
    name: 'ماجد القرني',
  ),
  DemoAccount(
    email: 'parent11@rafiq.demo',
    role: AppRoles.parent,
    name: 'ريم البلوي',
  ),
  DemoAccount(
    email: 'parent12@rafiq.demo',
    role: AppRoles.parent,
    name: 'حسن العمري',
  ),
  // Students 01–20
  DemoAccount(email: 'student01@rafiq.demo', role: AppRoles.student, name: 'أحمد محمد', note: 'متفوق'),
  DemoAccount(email: 'student02@rafiq.demo', role: AppRoles.student, name: 'سارة علي', note: 'متأخرة في الواجب'),
  DemoAccount(email: 'student03@rafiq.demo', role: AppRoles.student, name: 'عمر خالد'),
  DemoAccount(email: 'student04@rafiq.demo', role: AppRoles.student, name: 'نورة فهد'),
  DemoAccount(email: 'student05@rafiq.demo', role: AppRoles.student, name: 'يوسف سعد'),
  DemoAccount(email: 'student06@rafiq.demo', role: AppRoles.student, name: 'لينا ماجد'),
  DemoAccount(email: 'student07@rafiq.demo', role: AppRoles.student, name: 'كريم ناصر'),
  DemoAccount(email: 'student08@rafiq.demo', role: AppRoles.student, name: 'هدى بدر'),
  DemoAccount(email: 'student09@rafiq.demo', role: AppRoles.student, name: 'فيصل تركي', note: 'ملتحق حديثاً'),
  DemoAccount(email: 'student10@rafiq.demo', role: AppRoles.student, name: 'دانة وليد'),
  DemoAccount(email: 'student11@rafiq.demo', role: AppRoles.student, name: 'راكان سلمان'),
  DemoAccount(email: 'student12@rafiq.demo', role: AppRoles.student, name: 'جود إبراهيم'),
  DemoAccount(email: 'student13@rafiq.demo', role: AppRoles.student, name: 'تميم عادل'),
  DemoAccount(email: 'student14@rafiq.demo', role: AppRoles.student, name: 'ميساء حمد'),
  DemoAccount(email: 'student15@rafiq.demo', role: AppRoles.student, name: 'زياد طارق'),
  DemoAccount(email: 'student16@rafiq.demo', role: AppRoles.student, name: 'غادة سامر'),
  DemoAccount(email: 'student17@rafiq.demo', role: AppRoles.student, name: 'باسل أنور'),
  DemoAccount(email: 'student18@rafiq.demo', role: AppRoles.student, name: 'شهد فواز'),
  DemoAccount(email: 'student19@rafiq.demo', role: AppRoles.student, name: 'أنس جابر'),
  DemoAccount(email: 'student20@rafiq.demo', role: AppRoles.student, name: 'ريما صالح'),
];

/// Legacy emails still created (compat with older docs / habits).
const legacyCompatEmails = <String>[
  'supervisor@rafiq.demo',
  'student1@rafiq.demo',
  'student2@rafiq.demo',
];

Future<Map<String, User>> ensureAllDemoAuthUsers(
  FirebaseAuth auth, {
  required String password,
}) async {
  final out = <String, User>{};
  for (final a in demoAccountsCatalog) {
    out[a.email] = await ensureAuthUser(auth, email: a.email, password: password);
  }
  // Legacy aliases (same password) for older tooling.
  for (final email in legacyCompatEmails) {
    out[email] = await ensureAuthUser(auth, email: email, password: password);
  }
  return out;
}

Future<User> ensureAuthUser(
  FirebaseAuth auth, {
  required String email,
  required String password,
}) async {
  try {
    final cred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    stdout.writeln('  created Auth: $email');
    return cred.user!;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'email-already-in-use') {
      final cred = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      stdout.writeln('  reused Auth:  $email');
      return cred.user!;
    }
    rethrow;
  }
}

void printDemoCredentials(String password) {
  stdout.writeln('');
  stdout.writeln('════════════════════════════════════════════════════');
  stdout.writeln(' Demo Academy — credentials (password for all)');
  stdout.writeln('════════════════════════════════════════════════════');
  stdout.writeln('password: $password');
  stdout.writeln('');
  for (final a in demoAccountsCatalog) {
    stdout.writeln('${a.role.padRight(11)} ${a.email.padRight(28)} ${a.name}');
    if (a.note.isNotEmpty) stdout.writeln('${''.padRight(12)}→ ${a.note}');
  }
  stdout.writeln('────────────────────────────────────────────────────');
  stdout.writeln('halaqat: $demoHalaqaMorningId | $demoHalaqaAfternoonId | $demoHalaqaEveningId');
  stdout.writeln('academy: $demoAcademyId');
  stdout.writeln('Teacher Home login: teacher@rafiq.demo');
  stdout.writeln('════════════════════════════════════════════════════');
}

Future<void> seedDemoAcademyDataset(
  FirebaseFirestore db,
  FirebaseAuth auth, {
  required Map<String, User> users,
  required DateTime now,
}) async {
  final dayStart = AttendancePolicy.dayStart(now);
  final yesterday = dayStart.subtract(const Duration(days: 1));
  final tomorrow = dayStart.add(const Duration(days: 1));
  final nextWeek = dayStart.add(const Duration(days: 7));

  String uid(String email) => users[email]!.uid;

  final adminUid = uid('admin@rafiq.demo');
  final sup1 = uid('supervisor1@rafiq.demo');
  final sup2 = uid('supervisor2@rafiq.demo');
  final t1 = uid('teacher@rafiq.demo');
  final t2 = uid('teacher2@rafiq.demo');
  final t3 = uid('teacher3@rafiq.demo');

  final studentEmails = [
    for (var i = 1; i <= 20; i++) 'student${i.toString().padLeft(2, '0')}@rafiq.demo',
  ];
  final studentUids = [for (final e in studentEmails) uid(e)];
  final studentNames = {
    for (final a in demoAccountsCatalog.where((a) => a.role == AppRoles.student))
      a.email: a.name,
  };

  // Parent → children mapping (parent01 has two kids — outstanding scenario).
  final parentChildren = <String, List<String>>{
    'parent@rafiq.demo': [studentUids[0], studentUids[1]],
    'parent02@rafiq.demo': [studentUids[2], studentUids[3]],
    'parent03@rafiq.demo': [studentUids[4]],
    'parent04@rafiq.demo': [studentUids[5]],
    'parent05@rafiq.demo': [studentUids[6]],
    'parent06@rafiq.demo': [studentUids[7]],
    'parent07@rafiq.demo': [studentUids[8]],
    'parent08@rafiq.demo': [studentUids[9]],
    'parent09@rafiq.demo': [studentUids[10], studentUids[11]],
    'parent10@rafiq.demo': [studentUids[12]],
    'parent11@rafiq.demo': [studentUids[13], studentUids[14]],
    'parent12@rafiq.demo': [
      studentUids[15],
      studentUids[16],
      studentUids[17],
      studentUids[18],
      studentUids[19],
    ],
  };

  // Halaqa rosters
  final morningStudents = studentUids.sublist(0, 8);
  final afternoonStudents = studentUids.sublist(8, 14);
  final eveningStudents = studentUids.sublist(14, 20);

  stdout.writeln('Seeding academy document…');
  await db.collection('academies').doc(demoAcademyId).set({
    'name': 'أكاديمية رفيق للتحفيظ',
    'city': 'الرياض',
    'currentSemester': 'الفصل الدراسي الثاني 1447',
    'semesterStart': Timestamp.fromDate(dayStart.subtract(const Duration(days: 60))),
    'semesterEnd': Timestamp.fromDate(dayStart.add(const Duration(days: 60))),
    'timezone': 'Asia/Riyadh',
    'settings': {
      'attendanceGraceMinutes': 10,
      'weeklyQuotaDefault': 5,
      'enableParentAbsenceRequests': true,
    },
    'updatedAt': Timestamp.fromDate(now),
  }, SetOptions(merge: true));

  stdout.writeln('Seeding users + profiles…');
  for (final a in demoAccountsCatalog) {
    final u = users[a.email]!;
    await db.collection(FirestoreCollections.users).doc(u.uid).set(
      UserModel(
        uid: u.uid,
        name: a.name,
        role: a.role,
        phone: _phoneFor(a.email),
        email: a.email,
        isActive: true,
        createdAt: now,
      ).toFirestore(),
      SetOptions(merge: true),
    );
  }

  await db.collection(FirestoreCollections.teacherProfiles).doc(t1).set({
    'halaqatIds': [demoHalaqaMorningId, demoHalaqaAfternoonId],
    'performanceRating': 4.8,
    'weeklyQuota': 6,
  }, SetOptions(merge: true));
  await db.collection(FirestoreCollections.teacherProfiles).doc(t2).set({
    'halaqatIds': [demoHalaqaEveningId],
    'performanceRating': 4.6,
    'weeklyQuota': 5,
  }, SetOptions(merge: true));
  await db.collection(FirestoreCollections.teacherProfiles).doc(t3).set({
    'halaqatIds': <String>[],
    'performanceRating': 4.2,
    'weeklyQuota': 3,
  }, SetOptions(merge: true));

  for (final entry in parentChildren.entries) {
    await db.collection(FirestoreCollections.parentProfiles).doc(uid(entry.key)).set({
      'childrenIds': entry.value,
    }, SetOptions(merge: true));
  }

  stdout.writeln('Seeding halaqat…');
  final todayAr = _arabicWeekday(now.weekday);
  await _putHalaqa(
    db,
    id: demoHalaqaMorningId,
    name: 'حلقة الفجر',
    teacherId: t1,
    supervisorId: sup1,
    studentIds: morningStudents,
    schedule: [
      HalaqaScheduleModel(day: todayAr, startTime: '06:30', endTime: '08:00'),
      const HalaqaScheduleModel(day: 'الأربعاء', startTime: '06:30', endTime: '08:00'),
      const HalaqaScheduleModel(day: 'السبت', startTime: '06:30', endTime: '08:00'),
    ],
  );
  await _putHalaqa(
    db,
    id: demoHalaqaAfternoonId,
    name: 'حلقة العصر',
    teacherId: t1,
    supervisorId: sup2,
    studentIds: afternoonStudents,
    schedule: [
      HalaqaScheduleModel(day: todayAr, startTime: '16:00', endTime: '17:30'),
      const HalaqaScheduleModel(day: 'الاثنين', startTime: '16:00', endTime: '17:30'),
      const HalaqaScheduleModel(day: 'الخميس', startTime: '16:00', endTime: '17:30'),
    ],
  );
  await _putHalaqa(
    db,
    id: demoHalaqaEveningId,
    name: 'حلقة المساء',
    teacherId: t2,
    supervisorId: sup1,
    studentIds: eveningStudents,
    schedule: [
      HalaqaScheduleModel(day: todayAr, startTime: '19:30', endTime: '21:00'),
      const HalaqaScheduleModel(day: 'الثلاثاء', startTime: '19:30', endTime: '21:00'),
      const HalaqaScheduleModel(day: 'الجمعة', startTime: '19:30', endTime: '21:00'),
    ],
  );

  stdout.writeln('Seeding studentProfiles…');
  Future<void> profile(
    int index,
    String halaqaId,
    String halaqaName, {
    int points = 40,
    int streak = 3,
    List<String> badges = const [],
  }) async {
    final email = studentEmails[index];
    final id = studentUids[index];
    await db.collection(FirestoreCollections.studentProfiles).doc(id).set({
      'uid': id,
      'name': studentNames[email],
      'avatarId': index == 8 ? 'fox' : 'eagle',
      'level': index == 0 ? 5 : (index == 8 ? 1 : 2 + (index % 3)),
      'coins': 10 * (index + 1),
      'totalStars': index == 0 ? 48 : 8 + index,
      'points': index == 0 ? 920 : points + index * 7,
      'streakDays': index == 0 ? 21 : streak,
      'halaqaId': halaqaId,
      'halaqaName': halaqaName,
      'currentPlanName': index == 0 ? 'جزء تبارك' : 'سورة الملك',
      'overallProgressPercent': index == 0 ? 78 : 20 + index,
      'totalVersesMemorized': index == 0 ? 420 : 40 + index * 5,
      'completedJuz': index == 0 ? 3 : 0,
      'completedSurahs': index == 0 ? 12 : index % 4,
      'badges': badges,
      'createdAt': Timestamp.fromDate(
        index == 8 ? now.subtract(const Duration(days: 5)) : now.subtract(Duration(days: 90 - index)),
      ),
    }, SetOptions(merge: true));
  }

  for (var i = 0; i < 8; i++) {
    await profile(i, demoHalaqaMorningId, 'حلقة الفجر', badges: i == 0 ? ['متفوق'] : const []);
  }
  for (var i = 8; i < 14; i++) {
    await profile(i, demoHalaqaAfternoonId, 'حلقة العصر');
  }
  for (var i = 14; i < 20; i++) {
    await profile(i, demoHalaqaEveningId, 'حلقة المساء');
  }

  stdout.writeln('Seeding calendar sessions…');
  Future<void> session({
    required String id,
    required String title,
    required String halaqaId,
    required String halaqaName,
    required DateTime date,
    required String statusNote,
  }) {
    return db.collection(FirestoreCollections.calendarEvents).doc(id).set({
      'title': title,
      'type': 'session',
      'date': Timestamp.fromDate(date),
      'description': statusNote,
      'halaqaId': halaqaId,
      'halaqaName': halaqaName,
      'createdBy': adminUid,
      'createdAt': Timestamp.fromDate(now),
      'status': statusNote,
    }, SetOptions(merge: true));
  }

  await session(
    id: 'demo_session_morning_yday',
    title: 'جلسة حلقة الفجر',
    halaqaId: demoHalaqaMorningId,
    halaqaName: 'حلقة الفجر',
    date: yesterday.add(const Duration(hours: 6, minutes: 30)),
    statusNote: 'completed',
  );
  await session(
    id: 'demo_session_morning_today',
    title: 'جلسة حلقة الفجر',
    halaqaId: demoHalaqaMorningId,
    halaqaName: 'حلقة الفجر',
    date: dayStart.add(const Duration(hours: 6, minutes: 30)),
    statusNote: 'live_or_upcoming',
  );
  await session(
    id: 'demo_session_afternoon_today',
    title: 'جلسة حلقة العصر',
    halaqaId: demoHalaqaAfternoonId,
    halaqaName: 'حلقة العصر',
    date: dayStart.add(const Duration(hours: 16)),
    statusNote: 'upcoming',
  );
  await session(
    id: 'demo_session_evening_today',
    title: 'جلسة حلقة المساء',
    halaqaId: demoHalaqaEveningId,
    halaqaName: 'حلقة المساء',
    date: dayStart.add(const Duration(hours: 19, minutes: 30)),
    statusNote: 'upcoming',
  );
  await session(
    id: 'demo_session_morning_tmr',
    title: 'جلسة حلقة الفجر',
    halaqaId: demoHalaqaMorningId,
    halaqaName: 'حلقة الفجر',
    date: tomorrow.add(const Duration(hours: 6, minutes: 30)),
    statusNote: 'scheduled',
  );
  await session(
    id: 'demo_session_exam_next_week',
    title: 'اختبار تجويد — حلقة العصر',
    halaqaId: demoHalaqaAfternoonId,
    halaqaName: 'حلقة العصر',
    date: nextWeek.add(const Duration(hours: 16)),
    statusNote: 'scheduled',
  );

  stdout.writeln('Seeding attendance history…');
  await _seedAttendanceHistory(
    db,
    teacherId: t1,
    halaqaId: demoHalaqaMorningId,
    students: [
      for (var i = 0; i < morningStudents.length; i++)
        (id: morningStudents[i], name: studentNames[studentEmails[i]]!),
    ],
    dayStart: dayStart,
  );
  await _seedAttendanceHistory(
    db,
    teacherId: t1,
    halaqaId: demoHalaqaAfternoonId,
    students: [
      for (var i = 8; i < 14; i++)
        (id: studentUids[i], name: studentNames[studentEmails[i]]!),
    ],
    dayStart: dayStart,
  );

  stdout.writeln('Seeding homework…');
  await _seedHomeworkMix(
    db,
    teacherId: t1,
    halaqaId: demoHalaqaMorningId,
    studentIds: morningStudents,
    dayStart: dayStart,
  );

  stdout.writeln('Seeding reviews…');
  await _seedReviewsMix(
    db,
    teacherId: t1,
    halaqaId: demoHalaqaMorningId,
    students: [
      for (var i = 0; i < morningStudents.length; i++)
        (id: morningStudents[i], name: studentNames[studentEmails[i]]!),
    ],
    dayStart: dayStart,
  );

  stdout.writeln('Seeding awards…');
  await _seedAwards(
    db,
    teacherId: t1,
    supervisorId: sup1,
    studentId: studentUids[0],
    studentName: studentNames[studentEmails[0]]!,
    student2Id: studentUids[1],
    student2Name: studentNames[studentEmails[1]]!,
    halaqaId: demoHalaqaMorningId,
    now: now,
  );

  stdout.writeln('Seeding absence (excused scenario)…');
  final excuseDay = yesterday;
  final absenceId = AbsenceRequestIds.documentId(
    halaqaId: demoHalaqaMorningId,
    studentId: studentUids[1],
    date: excuseDay,
  );
  await db.collection(FirestoreCollections.absenceRequests).doc(absenceId).set({
    'studentId': studentUids[1],
    'halaqaId': demoHalaqaMorningId,
    'requestedBy': uid('parent@rafiq.demo'),
    'date': Timestamp.fromDate(AttendancePolicy.dayStart(excuseDay)),
    'reason': 'موعد طبي — معذور',
    'status': 'approved',
  });

  stdout.writeln('Seeding notifications + admin announcements…');
  await _seedNotificationsAndAnnouncements(
    db,
    now: now,
    teacherUid: t1,
    teacher2Uid: t2,
    parentUid: uid('parent@rafiq.demo'),
    studentUid: studentUids[0],
    student2Uid: studentUids[1],
  );

  stdout.writeln('Seeding posts…');
  await _seedPosts(
    db,
    now: now,
    adminUid: adminUid,
    teacherUid: t1,
    teacher2Uid: t2,
    supervisorUid: sup1,
  );

  // Touch legacy docs so older IDs still resolve for W1–W8 smoke paths.
  await db.collection(FirestoreCollections.halaqat).doc('seed_demo_halaqa').set({
    'name': 'حلقة التحفيظ التجريبية (legacy)',
    'teacherId': t1,
    'supervisorId': sup1,
    'studentIds': [studentUids[0], studentUids[1]],
    'schedule': [
      HalaqaScheduleModel(day: todayAr, startTime: '16:00', endTime: '18:00').toMap(),
    ],
    'meetingLink': 'https://meet.google.com/seed-demo-halaqa',
    'status': 'active',
  }, SetOptions(merge: true));
}

Future<void> _putHalaqa(
  FirebaseFirestore db, {
  required String id,
  required String name,
  required String teacherId,
  required String supervisorId,
  required List<String> studentIds,
  required List<HalaqaScheduleModel> schedule,
}) {
  return db.collection(FirestoreCollections.halaqat).doc(id).set({
    'name': name,
    'teacherId': teacherId,
    'supervisorId': supervisorId,
    'studentIds': studentIds,
    'schedule': schedule.map((s) => s.toMap()).toList(),
    'meetingLink': 'https://meet.google.com/$id',
    'status': 'active',
  }, SetOptions(merge: true));
}

Future<void> _seedAttendanceHistory(
  FirebaseFirestore db, {
  required String teacherId,
  required String halaqaId,
  required List<({String id, String name})> students,
  required DateTime dayStart,
}) async {
  final days = [
    dayStart.subtract(const Duration(days: 3)),
    dayStart.subtract(const Duration(days: 2)),
    dayStart.subtract(const Duration(days: 1)),
    dayStart,
  ];
  final pattern = [
    AttendanceStatus.present,
    AttendanceStatus.late,
    AttendanceStatus.absent,
    AttendanceStatus.present,
  ];

  for (final day in days) {
    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      // Yesterday: student index 1 treated as excused-absent (see absence request).
      var status = pattern[(i + day.day) % pattern.length];
      if (day == dayStart.subtract(const Duration(days: 1)) && i == 1) {
        status = AttendanceStatus.absent;
      }
      if (day == dayStart && i == 0) status = AttendanceStatus.present;
      if (day == dayStart && i == 1) status = AttendanceStatus.late;

      final sessionId = AttendancePolicy.sessionIdForDay(
        halaqaId: halaqaId,
        day: day,
      );
      final docId = AttendancePolicy.documentId(
        sessionId: sessionId,
        studentId: s.id,
      );
      final record = AttendanceRecordModel(
        id: docId,
        studentId: s.id,
        studentName: s.name,
        halaqaId: halaqaId,
        date: day,
        status: status,
        recordedBy: teacherId,
        sessionId: sessionId,
      );
      await db
          .collection(FirestoreCollections.attendanceRecords)
          .doc(docId)
          .set(record.toFirestore());
    }
  }
}

Future<void> _seedHomeworkMix(
  FirebaseFirestore db, {
  required String teacherId,
  required String halaqaId,
  required List<String> studentIds,
  required DateTime dayStart,
}) async {
  // Outstanding student — completed today
  await _putAssignment(
    db,
    id: 'demo_hw_${halaqaId}_s0_done',
    studentId: studentIds[0],
    teacherId: teacherId,
    halaqaId: halaqaId,
    due: dayStart,
    memorization: 'سورة الملك ١-١٥',
    review: 'سورة ق ١-١٠',
    submitted: true,
    completedAt: dayStart.add(const Duration(hours: 8)),
  );
  // Overdue / late
  await _putAssignment(
    db,
    id: 'demo_hw_${halaqaId}_s1_late',
    studentId: studentIds[1],
    teacherId: teacherId,
    halaqaId: halaqaId,
    due: dayStart.subtract(const Duration(days: 2)),
    memorization: 'سورة الملك ١-١٠',
    review: 'سورة ق ١-٥',
    submitted: false,
  );
  // Pending due tomorrow
  await _putAssignment(
    db,
    id: 'demo_hw_${halaqaId}_s2_pending',
    studentId: studentIds[2],
    teacherId: teacherId,
    halaqaId: halaqaId,
    due: dayStart.add(const Duration(days: 1)),
    memorization: 'سورة الملك ١١-٢٠',
    review: 'سورة الملك ١-١٠',
    submitted: false,
  );
  // Due today — still pending (feeds teacher pending tasks)
  for (var i = 3; i < studentIds.length; i++) {
    await _putAssignment(
      db,
      id: 'demo_hw_${halaqaId}_s${i}_today',
      studentId: studentIds[i],
      teacherId: teacherId,
      halaqaId: halaqaId,
      due: dayStart.add(const Duration(hours: 20)),
      memorization: 'سورة الملك ١-١٠',
      review: 'سورة ق ١-٥',
      submitted: false,
    );
  }
}

Future<void> _putAssignment(
  FirebaseFirestore db, {
  required String id,
  required String studentId,
  required String teacherId,
  required String halaqaId,
  required DateTime due,
  required String memorization,
  required String review,
  required bool submitted,
  DateTime? completedAt,
}) {
  final homework = AssignmentModel.defaultHomeworkFields(
    newMemorizationRange: memorization,
    reviewRange: review,
  );
  return db.collection(FirestoreCollections.assignments).doc(id).set({
    'studentId': studentId,
    'halaqaId': halaqaId,
    'assignedBy': teacherId,
    'newMemorizationRange': memorization,
    'reviewRange': review,
    'dueDate': Timestamp.fromDate(due),
    ...homework,
    'isSubmitted': submitted,
    if (submitted) 'status': 'completed',
    if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt),
    if (submitted)
      'tasks': (homework['tasks'] as List)
          .map((t) => {...Map<String, dynamic>.from(t as Map), 'isCompleted': true})
          .toList(),
  });
}

Future<void> _seedReviewsMix(
  FirebaseFirestore db, {
  required String teacherId,
  required String halaqaId,
  required List<({String id, String name})> students,
  required DateTime dayStart,
}) async {
  final grades = [
    RecitationGrade.excellent,
    RecitationGrade.veryGood,
    RecitationGrade.good,
    RecitationGrade.needsRetry,
  ];

  for (var i = 0; i < students.length; i++) {
    final s = students[i];
    final reviewed = RecitationRecordModel(
      id: 'demo_rec_${halaqaId}_${s.id}_reviewed',
      studentId: s.id,
      studentName: s.name,
      teacherId: teacherId,
      halaqaId: halaqaId,
      date: dayStart.subtract(Duration(hours: 6 + i)),
      type: RecitationType.memorization,
      versesRange: 'سورة الملك ١-١٠',
      grade: grades[i % grades.length],
      behaviorGrade: RecitationGrade.veryGood,
      notes: i == 0 ? 'أداء متميز' : null,
      reviewStatus: 'reviewed',
      submittedAt: dayStart.subtract(Duration(hours: 7 + i)),
    );
    await db
        .collection(FirestoreCollections.recitationRecords)
        .doc(reviewed.id)
        .set(reviewed.toFirestore());
  }

  // Pending reviews for teacher Home activities / agenda
  for (var i = 1; i <= 3; i++) {
    final s = students[i];
    final pending = RecitationRecordModel(
      id: 'demo_rec_${halaqaId}_${s.id}_pending',
      studentId: s.id,
      studentName: s.name,
      teacherId: teacherId,
      halaqaId: halaqaId,
      date: dayStart,
      type: RecitationType.memorization,
      versesRange: 'سورة الملك ١١-١٥',
      notes: 'بانتظار تقييم المعلم',
      reviewStatus: 'pending',
      submittedAt: dayStart.add(Duration(hours: i)),
    );
    await db
        .collection(FirestoreCollections.recitationRecords)
        .doc(pending.id)
        .set(pending.toFirestore());
  }
}

Future<void> _seedAwards(
  FirebaseFirestore db, {
  required String teacherId,
  required String supervisorId,
  required String studentId,
  required String studentName,
  required String student2Id,
  required String student2Name,
  required String halaqaId,
  required DateTime now,
}) async {
  final ts = Timestamp.fromDate(now.subtract(const Duration(hours: 2)));
  final teacherGrant = AchievementsFirestoreContract.teacherGrantFields(
    studentId: studentId,
    studentName: studentName,
    type: AwardType.studentOfWeek.firestoreKey,
    note: 'طالب الأسبوع — تميز في الحفظ',
    grantedBy: teacherId,
    halaqaId: halaqaId,
  );
  teacherGrant[AchievementsFirestoreContract.grantedAtField] = ts;
  teacherGrant[AchievementsFirestoreContract.dateField] = ts;
  await db
      .collection(FirestoreCollections.achievements)
      .doc('demo_ach_teacher_week')
      .set(Map<String, dynamic>.from(teacherGrant));

  final stars = AchievementsFirestoreContract.teacherGrantFields(
    studentId: student2Id,
    studentName: student2Name,
    type: AwardType.performanceStars.firestoreKey,
    note: 'نجمتان للتحفيظ',
    grantedBy: teacherId,
    halaqaId: halaqaId,
  );
  final ts2 = Timestamp.fromDate(now.subtract(const Duration(hours: 5)));
  stars[AchievementsFirestoreContract.grantedAtField] = ts2;
  stars[AchievementsFirestoreContract.dateField] = ts2;
  await db
      .collection(FirestoreCollections.achievements)
      .doc('demo_ach_teacher_stars')
      .set(Map<String, dynamic>.from(stars));

  final supervisorIssue = AchievementsFirestoreContract.supervisorIssueFields(
    studentId: studentId,
    type: 'badge',
    title: 'شارة إشرافية — التزام',
    issuedBy: supervisorId,
    halaqaId: halaqaId,
    at: now.subtract(const Duration(days: 1)),
  );
  await db
      .collection(FirestoreCollections.achievements)
      .doc('demo_ach_supervisor_badge')
      .set(Map<String, dynamic>.from(supervisorIssue));
}

Future<void> _seedNotificationsAndAnnouncements(
  FirebaseFirestore db, {
  required DateTime now,
  required String teacherUid,
  required String teacher2Uid,
  required String parentUid,
  required String studentUid,
  required String student2Uid,
}) async {
  Future<void> putNotif({
    required String id,
    required String audience,
    required String title,
    required String body,
    required String type,
    DateTime? at,
    List<String> readBy = const [],
    String? channel,
  }) {
    return db.collection(FirestoreCollections.notifications).doc(id).set({
      'audience': audience,
      'title': title,
      'body': body,
      'type': type,
      'hasAudioAlert': false,
      'createdAt': Timestamp.fromDate(at ?? now),
      'readBy': readBy,
      if (channel != null) 'channel': channel,
    });
  }

  // Admin announcements (Teacher Home banner uses newest with channel).
  final olderAnnouncement = AdminOpsBroadcast.notificationFields(
    title: 'إعلان إداري',
    body: 'تُعقد اجتماعات أولياء الأمور يوم الخميس بعد صلاة المغرب.',
    targetRole: AppRoles.teacher,
  );
  await db.collection(FirestoreCollections.notifications).doc('demo_announce_old').set({
    ...olderAnnouncement,
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
  });

  final newestAnnouncement = AdminOpsBroadcast.notificationFields(
    title: 'إعلان إداري',
    body: 'تذكير: موعد رفع التقييمات الشهرية غداً قبل الساعة 12 ظهراً',
    targetRole: AppRoles.teacher,
  );
  await db.collection(FirestoreCollections.notifications).doc('demo_announce_new').set({
    ...newestAnnouncement,
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
  });

  // Also broadcast to all roles (unread badge noise)
  final allAnnounce = AdminOpsBroadcast.notificationFields(
    title: 'إعلان إداري',
    body: 'يُرجى تحديث بيانات التواصل قبل نهاية الأسبوع.',
    targetRole: 'all',
  );
  await db.collection(FirestoreCollections.notifications).doc('demo_announce_all').set({
    ...allAnnounce,
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
  });

  await putNotif(
    id: 'demo_notif_teacher_assign',
    audience: teacherUid,
    title: 'تذكير مهام اليوم',
    body: 'لديك تسميعات معلّقة في حلقة الفجر.',
    type: NotificationTypes.assignment,
    at: now.subtract(const Duration(minutes: 40)),
  );
  await putNotif(
    id: 'demo_notif_teacher_read',
    audience: teacherUid,
    title: 'تم اعتماد استئذان',
    body: 'استئذان سارة علي ليوم أمس أصبح معتمداً.',
    type: NotificationTypes.attendance,
    at: now.subtract(const Duration(hours: 6)),
    readBy: [teacherUid],
  );
  await putNotif(
    id: 'demo_notif_teacher2',
    audience: teacher2Uid,
    title: 'حلقة المساء',
    body: 'تذكير بجلسة المساء اليوم 7:30.',
    type: NotificationTypes.sessionReminder,
  );
  await putNotif(
    id: 'demo_notif_student',
    audience: studentUid,
    title: 'واجب اليوم',
    body: 'سورة الملك ١-١٥ — يمكنك البدء من واجباتي.',
    type: NotificationTypes.assignment,
  );
  await putNotif(
    id: 'demo_notif_student2',
    audience: student2Uid,
    title: 'واجب متأخر',
    body: 'لديك تكليف متأخر — أنجزه اليوم.',
    type: NotificationTypes.assignment,
  );
  await putNotif(
    id: 'demo_notif_parent',
    audience: parentUid,
    title: 'تحديث حضور',
    body: 'تم تسجيل حضور أحمد اليوم في حلقة الفجر.',
    type: NotificationTypes.attendance,
  );
  await putNotif(
    id: 'demo_notif_parent_unread',
    audience: parentUid,
    title: 'تكليف جديد',
    body: 'تكليف جديد لسارة — سورة الملك.',
    type: NotificationTypes.assignment,
    at: now.subtract(const Duration(minutes: 15)),
  );
}

Future<void> _seedPosts(
  FirebaseFirestore db, {
  required DateTime now,
  required String adminUid,
  required String teacherUid,
  required String teacher2Uid,
  required String supervisorUid,
}) async {
  Future<void> post({
    required String id,
    required String authorId,
    required String authorName,
    required String content,
    required DateTime at,
    String audienceTarget = 'all',
    String? halaqaId,
    bool pinned = false,
  }) {
    return db.collection(FirestoreCollections.posts).doc(id).set({
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'halaqaId': halaqaId,
      'audience': halaqaId == null ? 'allHalaqat' : 'specificHalaqa',
      'audienceTarget': audienceTarget,
      'attachments': <Map<String, dynamic>>[],
      'createdAt': Timestamp.fromDate(at),
      'isPinned': pinned,
      'likedBy': <String>[],
      'commentsCount': 0,
    });
  }

  await post(
    id: 'demo_post_admin_1',
    authorId: adminUid,
    authorName: 'خالد عبدالرحمن',
    content: 'أهلاً بكم في الفصل الدراسي الثاني — نسأل الله التوفيق للجميع.',
    at: now.subtract(const Duration(days: 10)),
    pinned: true,
  );
  await post(
    id: 'demo_post_teacher_morning',
    authorId: teacherUid,
    authorName: 'عبدالله الحربي',
    content: 'أحسنتم يا حلقة الفجر — استمروا على ورد الملك هذا الأسبوع.',
    at: now.subtract(const Duration(days: 2)),
    audienceTarget: demoHalaqaMorningId,
    halaqaId: demoHalaqaMorningId,
  );
  await post(
    id: 'demo_post_teacher_evening',
    authorId: teacher2Uid,
    authorName: 'سارة العتيبي',
    content: 'تذكير حلقة المساء: إحضار المصاحف غداً إن شاء الله.',
    at: now.subtract(const Duration(hours: 8)),
    audienceTarget: demoHalaqaEveningId,
    halaqaId: demoHalaqaEveningId,
  );
  await post(
    id: 'demo_post_supervisor',
    authorId: supervisorUid,
    authorName: 'فهد السبيعي',
    content: 'نشكر المعلمين على انتظام الحضور هذا الأسبوع.',
    at: now.subtract(const Duration(days: 1)),
  );
}

String _arabicWeekday(int weekday) => switch (weekday) {
  DateTime.monday => 'الاثنين',
  DateTime.tuesday => 'الثلاثاء',
  DateTime.wednesday => 'الأربعاء',
  DateTime.thursday => 'الخميس',
  DateTime.friday => 'الجمعة',
  DateTime.saturday => 'السبت',
  _ => 'الأحد',
};

String _phoneFor(String email) {
  final hash = email.hashCode.abs() % 100000000;
  return '05${hash.toString().padLeft(8, '0')}';
}
