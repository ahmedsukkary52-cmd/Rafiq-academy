/// Full-academy Firestore seeder for manual W1–W8 testing (developer-only).
///
/// Creates Auth accounts + Firestore docs using existing field shapes / models.
/// Does **not** modify production app code.
///
/// Run from project root:
///
/// ```bash
/// flutter run -d windows -t tool/seed_firestore.dart
/// ```
///
/// Optional:
///   --password=YourPassword123!
///   --dart-define=SEED_PASSWORD=YourPassword123!
///
/// Idempotent where possible: fixed seed document IDs; Auth emails are reused
/// (sign-in) if they already exist.
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/auth/data/models/user_model.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';
import 'package:rafiq_academy/features/student/data/models/assignment_model.dart';
import 'package:rafiq_academy/features/student/data/models/halaqa_schedule_model.dart';
import 'package:rafiq_academy/features/student/data/models/recitation_record_model.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/data/models/attendance_record_model.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/firebase_options.dart';
import 'package:rafiq_academy/shared/data/achievements_firestore_contract.dart';
import 'package:rafiq_academy/shared/utils/absence_request_ids.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

// ── Stable seed document IDs ─────────────────────────────────────────────────

const _halaqaId = 'seed_demo_halaqa';
const _assignment1Id = 'seed_demo_assignment_s1';
const _assignment2Id = 'seed_demo_assignment_s2';
const _recitationReviewedId = 'seed_demo_rec_reviewed';
const _recitationPendingId = 'seed_demo_rec_pending';
const _achievementTeacherId = 'seed_demo_ach_teacher';
const _achievementSupervisorId = 'seed_demo_ach_supervisor';
const _notifTeacherId = 'seed_demo_notif_teacher';
const _notifParentId = 'seed_demo_notif_parent';
const _notifStudentId = 'seed_demo_notif_student';
const _reviewScheduleId = 'seed_demo_review_schedule';

const _defaultPassword = 'SeedDemo123!';

Future<void> main(List<String> rawArgs) async {
  WidgetsFlutterBinding.ensureInitialized();

  final password = _readPassword(rawArgs);
  stdout.writeln('Initializing Firebase…');
  // Android options so the tool runs on desktop without a Windows Firebase entry.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);

  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  final now = DateTime.now();
  final dayStart = AttendancePolicy.dayStart(now);

  stdout.writeln('Creating Auth accounts…');
  final admin = await _ensureAuthUser(
    auth,
    email: 'admin@rafiq.demo',
    password: password,
  );
  final teacher = await _ensureAuthUser(
    auth,
    email: 'teacher@rafiq.demo',
    password: password,
  );
  final supervisor = await _ensureAuthUser(
    auth,
    email: 'supervisor@rafiq.demo',
    password: password,
  );
  final parent = await _ensureAuthUser(
    auth,
    email: 'parent@rafiq.demo',
    password: password,
  );
  final student1 = await _ensureAuthUser(
    auth,
    email: 'student1@rafiq.demo',
    password: password,
  );
  final student2 = await _ensureAuthUser(
    auth,
    email: 'student2@rafiq.demo',
    password: password,
  );

  // Prefer writing while signed in as teacher (typical rules allow staff writes).
  await auth.signInWithEmailAndPassword(
    email: 'teacher@rafiq.demo',
    password: password,
  );

  stdout.writeln('Seeding Firestore (W1–W8 demo)…');
  await _seedUsersAndProfiles(
    db,
    now: now,
    adminUid: admin.uid,
    teacherUid: teacher.uid,
    supervisorUid: supervisor.uid,
    parentUid: parent.uid,
    student1Uid: student1.uid,
    student2Uid: student2.uid,
  );

  await _seedHalaqa(
    db,
    teacherUid: teacher.uid,
    supervisorUid: supervisor.uid,
    student1Uid: student1.uid,
    student2Uid: student2.uid,
    today: now,
  );

  await _seedMembershipLinks(
    db,
    student1Uid: student1.uid,
    student2Uid: student2.uid,
    student1Name: 'أحمد محمد',
    student2Name: 'سارة علي',
    now: now,
  );

  await _seedAssignments(
    db,
    teacherUid: teacher.uid,
    student1Uid: student1.uid,
    student2Uid: student2.uid,
    dueDate: dayStart.add(const Duration(days: 2)),
  );

  await _seedAttendance(
    db,
    teacherUid: teacher.uid,
    student1Uid: student1.uid,
    student2Uid: student2.uid,
    dayStart: dayStart,
  );

  await _seedReviews(
    db,
    teacherUid: teacher.uid,
    student1Uid: student1.uid,
    student2Uid: student2.uid,
    dayStart: dayStart,
  );

  await _seedReviewSchedule(db, student1Uid: student1.uid, dayStart: dayStart);

  await _seedAbsenceRequest(
    db,
    parentUid: parent.uid,
    student2Uid: student2.uid,
    dayStart: dayStart,
  );

  await _seedAchievements(
    db,
    teacherUid: teacher.uid,
    supervisorUid: supervisor.uid,
    student1Uid: student1.uid,
    now: now,
  );

  await _seedNotifications(
    db,
    teacherUid: teacher.uid,
    parentUid: parent.uid,
    student1Uid: student1.uid,
    now: now,
  );

  stdout.writeln('');
  stdout.writeln('════════════════════════════════════════');
  stdout.writeln(' Seed complete — demo accounts');
  stdout.writeln('════════════════════════════════════════');
  _printAccount('admin@rafiq.demo', password, AppRoles.admin);
  _printAccount('teacher@rafiq.demo', password, AppRoles.teacher);
  _printAccount('supervisor@rafiq.demo', password, AppRoles.supervisor);
  _printAccount('parent@rafiq.demo', password, AppRoles.parent);
  _printAccount('student1@rafiq.demo', password, AppRoles.student);
  _printAccount('student2@rafiq.demo', password, AppRoles.student);
  stdout.writeln('────────────────────────────────────────');
  stdout.writeln('halaqaId: $_halaqaId');
  stdout.writeln('student1 uid: ${student1.uid}');
  stdout.writeln('student2 uid: ${student2.uid}');
  stdout.writeln('════════════════════════════════════════');
  exit(0);
}

void _printAccount(String email, String password, String role) {
  stdout.writeln('email:    $email');
  stdout.writeln('password: $password');
  stdout.writeln('role:     $role');
  stdout.writeln('');
}

String _readPassword(List<String> rawArgs) {
  const fromDefine = String.fromEnvironment('SEED_PASSWORD');
  if (fromDefine.isNotEmpty) return fromDefine;
  for (final a in rawArgs) {
    if (a.startsWith('--password=')) {
      return a.substring('--password='.length);
    }
  }
  return _defaultPassword;
}

Future<User> _ensureAuthUser(
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

// ── users + role profiles ────────────────────────────────────────────────────

Future<void> _seedUsersAndProfiles(
  FirebaseFirestore db, {
  required DateTime now,
  required String adminUid,
  required String teacherUid,
  required String supervisorUid,
  required String parentUid,
  required String student1Uid,
  required String student2Uid,
}) async {
  Future<void> putUser({
    required String uid,
    required String name,
    required String role,
    required String phone,
    required String email,
  }) {
    final model = UserModel(
      uid: uid,
      name: name,
      role: role,
      phone: phone,
      email: email,
      isActive: true,
      createdAt: now,
    );
    return db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .set(model.toFirestore(), SetOptions(merge: true));
  }

  await putUser(
    uid: adminUid,
    name: 'مدير الأكاديمية',
    role: AppRoles.admin,
    phone: '0500000000',
    email: 'admin@rafiq.demo',
  );
  await putUser(
    uid: teacherUid,
    name: 'المعلم التجريبي',
    role: AppRoles.teacher,
    phone: '0500000001',
    email: 'teacher@rafiq.demo',
  );
  await putUser(
    uid: supervisorUid,
    name: 'المشرف التجريبي',
    role: AppRoles.supervisor,
    phone: '0500000002',
    email: 'supervisor@rafiq.demo',
  );
  await putUser(
    uid: parentUid,
    name: 'ولي الأمر التجريبي',
    role: AppRoles.parent,
    phone: '0500000003',
    email: 'parent@rafiq.demo',
  );
  await putUser(
    uid: student1Uid,
    name: 'أحمد محمد',
    role: AppRoles.student,
    phone: '0500000004',
    email: 'student1@rafiq.demo',
  );
  await putUser(
    uid: student2Uid,
    name: 'سارة علي',
    role: AppRoles.student,
    phone: '0500000005',
    email: 'student2@rafiq.demo',
  );

  // Optional teacher profile (admin management surfaces).
  await db.collection(FirestoreCollections.teacherProfiles).doc(teacherUid).set(
    {
      'halaqatIds': [_halaqaId],
      'performanceRating': 4.5,
      'weeklyQuota': 5,
    },
    SetOptions(merge: true),
  );

  // Parent ↔ children (W4 / W7).
  await db.collection(FirestoreCollections.parentProfiles).doc(parentUid).set({
    'childrenIds': [student1Uid, student2Uid],
  }, SetOptions(merge: true));
}

Future<void> _seedMembershipLinks(
  FirebaseFirestore db, {
  required String student1Uid,
  required String student2Uid,
  required String student1Name,
  required String student2Name,
  required DateTime now,
}) async {
  // W8 admit shape: studentProfiles.halaqaId + users.isActive (already true).
  await db
      .collection(FirestoreCollections.studentProfiles)
      .doc(student1Uid)
      .set(
        _studentProfileMap(
          uid: student1Uid,
          name: student1Name,
          halaqaId: _halaqaId,
          createdAt: now,
        ),
        SetOptions(merge: true),
      );
  await db
      .collection(FirestoreCollections.studentProfiles)
      .doc(student2Uid)
      .set(
        _studentProfileMap(
          uid: student2Uid,
          name: student2Name,
          halaqaId: _halaqaId,
          createdAt: now,
        ),
        SetOptions(merge: true),
      );
}

Map<String, dynamic> _studentProfileMap({
  required String uid,
  required String name,
  required String halaqaId,
  required DateTime createdAt,
}) {
  return {
    'uid': uid,
    'name': name,
    'avatarId': 'fox',
    'level': 1,
    'coins': 0,
    'totalStars': 0,
    'points': 0,
    'streakDays': 0,
    'halaqaId': halaqaId,
    'halaqaName': 'حلقة التحفيظ التجريبية',
    'currentPlanName': '',
    'overallProgressPercent': 0,
    'totalVersesMemorized': 0,
    'completedJuz': 0,
    'completedSurahs': 0,
    'badges': <String>[],
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

// ── halaqa + schedule (session today for W3/W6) ──────────────────────────────

Future<void> _seedHalaqa(
  FirebaseFirestore db, {
  required String teacherUid,
  required String supervisorUid,
  required String student1Uid,
  required String student2Uid,
  required DateTime today,
}) async {
  final schedule = HalaqaScheduleModel(
    day: _arabicWeekday(today.weekday),
    startTime: '16:00',
    endTime: '18:00',
  );
  // Extra weekday so weekly schedule UI is non-empty mid-week.
  const midweek = HalaqaScheduleModel(
    day: 'الأربعاء',
    startTime: '16:00',
    endTime: '18:00',
  );

  await db.collection(FirestoreCollections.halaqat).doc(_halaqaId).set({
    'name': 'حلقة التحفيظ التجريبية',
    'teacherId': teacherUid,
    'supervisorId': supervisorUid,
    'studentIds': [student1Uid, student2Uid],
    'schedule': [schedule.toMap(), midweek.toMap()],
    'meetingLink': 'https://meet.google.com/seed-demo-halaqa',
    'status': 'active',
  }, SetOptions(merge: true));
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

// ── W1 assignments (one doc per student) ─────────────────────────────────────

Future<void> _seedAssignments(
  FirebaseFirestore db, {
  required String teacherUid,
  required String student1Uid,
  required String student2Uid,
  required DateTime dueDate,
}) async {
  const memorization = 'سورة الملك ١-١٠';
  const review = 'سورة ق ١-٥';
  final homework = AssignmentModel.defaultHomeworkFields(
    newMemorizationRange: memorization,
    reviewRange: review,
  );

  Future<void> write(String docId, String studentId) {
    return db.collection(FirestoreCollections.assignments).doc(docId).set({
      'studentId': studentId,
      'halaqaId': _halaqaId,
      'assignedBy': teacherUid,
      'newMemorizationRange': memorization,
      'reviewRange': review,
      'dueDate': Timestamp.fromDate(dueDate),
      ...homework,
    });
  }

  await write(_assignment1Id, student1Uid);
  await write(_assignment2Id, student2Uid);
}

// ── W2 attendance (deterministic ids) ────────────────────────────────────────

Future<void> _seedAttendance(
  FirebaseFirestore db, {
  required String teacherUid,
  required String student1Uid,
  required String student2Uid,
  required DateTime dayStart,
}) async {
  final id1 = AttendancePolicy.documentId(
    halaqaId: _halaqaId,
    studentId: student1Uid,
    date: dayStart,
  );
  final id2 = AttendancePolicy.documentId(
    halaqaId: _halaqaId,
    studentId: student2Uid,
    date: dayStart,
  );

  final present = AttendanceRecordModel(
    id: id1,
    studentId: student1Uid,
    studentName: 'أحمد محمد',
    halaqaId: _halaqaId,
    date: dayStart,
    status: AttendanceStatus.present,
    recordedBy: teacherUid,
  );
  final late = AttendanceRecordModel(
    id: id2,
    studentId: student2Uid,
    studentName: 'سارة علي',
    halaqaId: _halaqaId,
    date: dayStart,
    status: AttendanceStatus.late,
    recordedBy: teacherUid,
  );

  await db
      .collection(FirestoreCollections.attendanceRecords)
      .doc(id1)
      .set(present.toFirestore());
  await db
      .collection(FirestoreCollections.attendanceRecords)
      .doc(id2)
      .set(late.toFirestore());
}

// ── W1 reviews (recitationRecords) ───────────────────────────────────────────

Future<void> _seedReviews(
  FirebaseFirestore db, {
  required String teacherUid,
  required String student1Uid,
  required String student2Uid,
  required DateTime dayStart,
}) async {
  final reviewed = RecitationRecordModel(
    id: _recitationReviewedId,
    studentId: student1Uid,
    studentName: 'أحمد محمد',
    teacherId: teacherUid,
    halaqaId: _halaqaId,
    date: dayStart,
    type: RecitationType.memorization,
    versesRange: 'سورة الملك ١-١٠',
    grade: RecitationGrade.excellent,
    behaviorGrade: RecitationGrade.veryGood,
    notes: 'أداء ممتاز في الحفظ',
    reviewStatus: 'reviewed',
    assignmentId: _assignment1Id,
    taskId: 't3',
  );
  final pending = RecitationRecordModel(
    id: _recitationPendingId,
    studentId: student2Uid,
    studentName: 'سارة علي',
    teacherId: teacherUid,
    halaqaId: _halaqaId,
    date: dayStart,
    type: RecitationType.memorization,
    versesRange: 'سورة الملك ١-٥',
    notes: 'تسميع بانتظار مراجعة المعلم',
    reviewStatus: 'pending',
    assignmentId: _assignment2Id,
    taskId: 't3',
  );

  await db
      .collection(FirestoreCollections.recitationRecords)
      .doc(_recitationReviewedId)
      .set(reviewed.toFirestore());
  await db
      .collection(FirestoreCollections.recitationRecords)
      .doc(_recitationPendingId)
      .set(pending.toFirestore());
}

/// Student review-schedule surface (existing `reviewSchedules` collection).
Future<void> _seedReviewSchedule(
  FirebaseFirestore db, {
  required String student1Uid,
  required DateTime dayStart,
}) async {
  await db
      .collection(FirestoreCollections.reviewSchedules)
      .doc(_reviewScheduleId)
      .set({
        'studentId': student1Uid,
        'date': Timestamp.fromDate(dayStart.add(const Duration(days: 1))),
        'surahFrom': 'الملك',
        'ayahFrom': 1,
        'surahTo': 'الملك',
        'ayahTo': 10,
        'status': 'pending',
      }, SetOptions(merge: true));
}

// ── W7 absence request (pending for teacher review) ──────────────────────────

Future<void> _seedAbsenceRequest(
  FirebaseFirestore db, {
  required String parentUid,
  required String student2Uid,
  required DateTime dayStart,
}) async {
  // Use tomorrow so today's attendance SSOT and استئذان don't collide on same day.
  final requestDay = dayStart.add(const Duration(days: 1));
  final id = AbsenceRequestIds.documentId(
    halaqaId: _halaqaId,
    studentId: student2Uid,
    date: requestDay,
  );

  await db.collection(FirestoreCollections.absenceRequests).doc(id).set({
    'studentId': student2Uid,
    'halaqaId': _halaqaId,
    'requestedBy': parentUid,
    'date': Timestamp.fromDate(AttendancePolicy.dayStart(requestDay)),
    'reason': 'موعد طبي — بذرة تجريبية',
    'status': 'pending',
  });
}

// ── H7 achievements (dual-write) ─────────────────────────────────────────────

Future<void> _seedAchievements(
  FirebaseFirestore db, {
  required String teacherUid,
  required String supervisorUid,
  required String student1Uid,
  required DateTime now,
}) async {
  final ts = Timestamp.fromDate(now);

  final teacherGrant = AchievementsFirestoreContract.teacherGrantFields(
    studentId: student1Uid,
    studentName: 'أحمد محمد',
    type: AwardType.studentOfWeek.firestoreKey,
    note: 'تميز في حلقة التحفيظ',
    grantedBy: teacherUid,
    halaqaId: _halaqaId,
  );
  // Replace serverTimestamp with concrete Timestamp for immediate reads.
  teacherGrant[AchievementsFirestoreContract.grantedAtField] = ts;
  teacherGrant[AchievementsFirestoreContract.dateField] = ts;

  await db
      .collection(FirestoreCollections.achievements)
      .doc(_achievementTeacherId)
      .set(Map<String, dynamic>.from(teacherGrant));

  final supervisorIssue = AchievementsFirestoreContract.supervisorIssueFields(
    studentId: student1Uid,
    type: 'badge',
    title: 'شارة من المشرف',
    issuedBy: supervisorUid,
    halaqaId: _halaqaId,
    at: now,
  );

  await db
      .collection(FirestoreCollections.achievements)
      .doc(_achievementSupervisorId)
      .set(Map<String, dynamic>.from(supervisorIssue));
}

// ── Notifications (W4/W5 inbox projections) ──────────────────────────────────

Future<void> _seedNotifications(
  FirebaseFirestore db, {
  required String teacherUid,
  required String parentUid,
  required String student1Uid,
  required DateTime now,
}) async {
  Future<void> put({
    required String id,
    required String audience,
    required String title,
    required String body,
    required String type,
  }) {
    return db.collection(FirestoreCollections.notifications).doc(id).set({
      'audience': audience,
      'title': title,
      'body': body,
      'type': type,
      'hasAudioAlert': false,
      'createdAt': Timestamp.fromDate(now),
      'readBy': <String>[],
    });
  }

  await put(
    id: _notifTeacherId,
    audience: teacherUid,
    title: 'بيانات البذرة جاهزة',
    body: 'يمكنك تجربة الحضور والتكليفات ومراجعة التسميع واستئذان اليوم.',
    type: NotificationTypes.general,
  );
  await put(
    id: _notifParentId,
    audience: parentUid,
    title: 'تكليف جديد لابنك',
    body: 'سورة الملك ١-١٠ — بذرة تجريبية (W5 awareness).',
    type: NotificationTypes.assignment,
  );
  await put(
    id: _notifStudentId,
    audience: student1Uid,
    title: 'واجب اليوم',
    body: 'افتح واجباتي لإكمال مهام القراءة والاستماع.',
    type: NotificationTypes.assignment,
  );
}
