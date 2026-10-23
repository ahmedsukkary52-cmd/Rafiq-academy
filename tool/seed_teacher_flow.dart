/// Teacher-flow Firestore seed utility (developer / admin-only).
///
/// Inserts the minimum documents to unlock Teacher screens with real data.
/// Reuses existing app models / field shapes. Does not change app architecture.
///
/// Run (from project root), with an existing teacher Auth account, against the
/// local emulators only (`--target=emulator`; real projects are refused):
///
/// ```bash
/// flutter run -d windows -t tool/seed_teacher_flow.dart --dart-define=SEED_TARGET=emulator --dart-define=SEED_TEACHER_UID=<uid> --dart-define=SEED_TEACHER_EMAIL=<email> --dart-define=SEED_TEACHER_PASSWORD=<password>
/// ```
///
/// `--target=<target>`, `--teacher-uid=<uid>`, `--teacher-email=<email>` and
/// `--teacher-password=<password>` entrypoint args are accepted too.
///
/// Optional overrides:
///   --teacher-name=...  --meeting-link=...
///
/// Idempotent: fixed document IDs under `seed_*` so re-runs overwrite the same docs.
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/auth/data/models/user_model.dart';
import 'package:rafiq_academy/features/awards/data/models/granted_award_model.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';
import 'package:rafiq_academy/features/student/data/models/halaqa_schedule_model.dart';
import 'package:rafiq_academy/features/student/data/models/recitation_record_model.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/data/models/attendance_record_model.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

import 'seed_firebase.dart';
import 'seed_target.dart';

// ── Stable seed IDs (idempotent re-runs) ─────────────────────────────────────

const _student1Id = 'seed_student_1';
const _student2Id = 'seed_student_2';
const _halaqaId = 'seed_teacher_halaqa';
const _recitationReviewedId = 'seed_rec_reviewed';
const _recitationPendingId = 'seed_rec_pending';
const _achievementId = 'seed_achievement_1';
const _notificationId = 'seed_notif_teacher';

const _student1Name = 'أحمد محمد';
const _student2Name = 'عمر خالد';
const _defaultTeacherName = 'المعلم التجريبي';
const _defaultMeetingLink = 'https://meet.google.com/seed-teacher-halaqa';

Future<void> main(List<String> rawArgs) async {
  WidgetsFlutterBinding.ensureInitialized();

  final args = _SeedArgs.parse(rawArgs);
  final code = await runGuardedSeed(
    args: rawArgs,
    definedTarget: const String.fromEnvironment('SEED_TARGET'),
    preflight: (_) {
      if (args.teacherUid.isEmpty) {
        throw const SeedTargetException(
          'Missing teacher uid. Pass --teacher-uid=<uid> or '
          '--dart-define=SEED_TEACHER_UID=<uid>. '
          'Teacher Auth account must already exist.',
        );
      }
    },
    initialize: (config) async {
      await initializeSeedFirebase(config);
      await _signInTeacher(args);
    },
    seed: (_) async {
      final result = await _seedTeacherFlow(FirebaseFirestore.instance, args);
      stdout.writeln('Seed complete.');
      stdout.writeln('  teacherUid : ${result.teacherUid}');
      stdout.writeln('  student1   : ${result.student1Id}');
      stdout.writeln('  student2   : ${result.student2Id}');
      stdout.writeln('  halaqaId   : ${result.halaqaId}');
    },
    out: stdout.writeln,
    err: stderr.writeln,
  );
  exit(code);
}

Future<void> _signInTeacher(_SeedArgs args) async {
  final auth = FirebaseAuth.instance;
  if (args.teacherEmail.isNotEmpty && args.teacherPassword.isNotEmpty) {
    stdout.writeln('Signing in as ${args.teacherEmail}…');
    await auth.signInWithEmailAndPassword(
      email: args.teacherEmail,
      password: args.teacherPassword,
    );
    if (auth.currentUser?.uid != args.teacherUid) {
      throw SeedTargetException(
        'Signed-in uid (${auth.currentUser?.uid}) does not match '
        'SEED_TEACHER_UID (${args.teacherUid}).',
      );
    }
  } else {
    stdout.writeln(
      'No email/password provided — writing with current Auth state '
      '(may fail if Firestore rules require auth).',
    );
  }
}

Future<_SeedResult> _seedTeacherFlow(
  FirebaseFirestore db,
  _SeedArgs args,
) async {
  final teacherUid = args.teacherUid;
  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);
  final teacherName = args.teacherName;

  // 1) Teacher users/{teacherUid} (email stays in Firebase Auth only)
  final teacherUser = UserModel(
    uid: teacherUid,
    name: teacherName,
    role: AppRoles.teacher,
    isActive: true,
    createdAt: now,
  );
  await db
      .collection(FirestoreCollections.users)
      .doc(teacherUid)
      .set(teacherUser.toFirestore(), SetOptions(merge: true));

  // 2) Student users
  final student1 = UserModel(
    uid: _student1Id,
    name: _student1Name,
    role: AppRoles.student,
    isActive: true,
    createdAt: now,
  );
  final student2 = UserModel(
    uid: _student2Id,
    name: _student2Name,
    role: AppRoles.student,
    isActive: true,
    createdAt: now,
  );
  await db
      .collection(FirestoreCollections.users)
      .doc(_student1Id)
      .set(student1.toFirestore(), SetOptions(merge: true));
  await db
      .collection(FirestoreCollections.users)
      .doc(_student2Id)
      .set(student2.toFirestore(), SetOptions(merge: true));

  // 3) studentProfiles — same field set as AuthRemoteDatasourceImpl._createStudentProfile
  //    plus halaqaId link used by admin enrollment / profile page.
  await db
      .collection(FirestoreCollections.studentProfiles)
      .doc(_student1Id)
      .set(
        _studentProfileMap(
          uid: _student1Id,
          name: _student1Name,
          halaqaId: _halaqaId,
          createdAt: now,
        ),
        SetOptions(merge: true),
      );
  await db
      .collection(FirestoreCollections.studentProfiles)
      .doc(_student2Id)
      .set(
        _studentProfileMap(
          uid: _student2Id,
          name: _student2Name,
          halaqaId: _halaqaId,
          createdAt: now,
        ),
        SetOptions(merge: true),
      );

  // 4) One active halaqa (fields match HalaqaModel.fromFirestore)
  const schedule = HalaqaScheduleModel(
    day: 'الأحد',
    startTime: '16:00',
    endTime: '18:00',
  );
  await db.collection(FirestoreCollections.halaqat).doc(_halaqaId).set({
    'name': 'حلقة التسميع التجريبية',
    'teacherId': teacherUid,
    'supervisorId': '',
    'studentIds': [_student1Id, _student2Id],
    'schedule': [schedule.toMap()],
    'meetingLink': args.meetingLink,
    'status': 'active',
  }, SetOptions(merge: true));

  // 5) Attendance today — present + late (session-scoped ids)
  final sessionId = AttendancePolicy.sessionIdForDay(
    halaqaId: _halaqaId,
    day: dayStart,
  );
  final presentId = AttendancePolicy.documentId(
    sessionId: sessionId,
    studentId: _student1Id,
  );
  final lateId = AttendancePolicy.documentId(
    sessionId: sessionId,
    studentId: _student2Id,
  );
  final present = AttendanceRecordModel(
    id: presentId,
    studentId: _student1Id,
    studentName: _student1Name,
    halaqaId: _halaqaId,
    date: dayStart,
    status: AttendanceStatus.present,
    recordedBy: teacherUid,
    sessionId: sessionId,
  );
  final late = AttendanceRecordModel(
    id: lateId,
    studentId: _student2Id,
    studentName: _student2Name,
    halaqaId: _halaqaId,
    date: dayStart,
    status: AttendanceStatus.late,
    recordedBy: teacherUid,
    sessionId: sessionId,
  );
  await db
      .collection(FirestoreCollections.attendanceRecords)
      .doc(presentId)
      .set(present.toFirestore());
  await db
      .collection(FirestoreCollections.attendanceRecords)
      .doc(lateId)
      .set(late.toFirestore());

  // 6) Recitation — reviewed + pending (RecitationRecordModel.toFirestore)
  final reviewed = RecitationRecordModel(
    id: _recitationReviewedId,
    studentId: _student1Id,
    studentName: _student1Name,
    teacherId: teacherUid,
    halaqaId: _halaqaId,
    date: dayStart,
    type: RecitationType.memorization,
    versesRange: 'سورة الملك ١-١٠',
    grade: RecitationGrade.excellent,
    behaviorGrade: RecitationGrade.veryGood,
    notes: 'أداء ممتاز في الحفظ',
    reviewStatus: 'reviewed',
  );
  final pending = RecitationRecordModel(
    id: _recitationPendingId,
    studentId: _student2Id,
    studentName: _student2Name,
    teacherId: teacherUid,
    halaqaId: _halaqaId,
    date: dayStart,
    type: RecitationType.memorization,
    versesRange: 'سورة الملك ١-٥',
    notes: 'تسميع مرسل من الطالب — بانتظار المراجعة',
    reviewStatus: 'pending',
  );
  await db
      .collection(FirestoreCollections.recitationRecords)
      .doc(_recitationReviewedId)
      .set(reviewed.toFirestore());
  await db
      .collection(FirestoreCollections.recitationRecords)
      .doc(_recitationPendingId)
      .set(pending.toFirestore());

  // 7) One achievement / granted award (GrantedAwardModel.toFirestore)
  final award = GrantedAwardModel(
    id: _achievementId,
    studentId: _student1Id,
    studentName: _student1Name,
    type: AwardType.studentOfWeek,
    note: 'تميز في حلقة التسميع',
    grantedBy: teacherUid,
    halaqaId: _halaqaId,
    grantedAt: now,
  );
  // toFirestore uses serverTimestamp for grantedAt — replace with concrete Timestamp
  // so the seed is readable immediately and matches fromFirestore casting.
  final awardData = Map<String, dynamic>.from(award.toFirestore())
    ..['grantedAt'] = Timestamp.fromDate(now);
  await db
      .collection(FirestoreCollections.achievements)
      .doc(_achievementId)
      .set(awardData);

  // 8) One notification targeting the teacher
  //    Fields match NotificationModel.fromFirestore + audience used by the query.
  await db
      .collection(FirestoreCollections.notifications)
      .doc(_notificationId)
      .set({
        'audience': teacherUid,
        'title': 'مرحباً بك في حلقتك التجريبية',
        'body': 'بيانات البذرة جاهزة — يمكنك تجربة الحضور والتقييمات والجوائز.',
        'type': NotificationTypes.sessionReminder,
        'hasAudioAlert': false,
        'createdAt': Timestamp.fromDate(now),
        'readBy': <String>[],
      });

  return _SeedResult(
    teacherUid: teacherUid,
    student1Id: _student1Id,
    student2Id: _student2Id,
    halaqaId: _halaqaId,
  );
}

/// Profile payload aligned with AuthRemoteDatasourceImpl._createStudentProfile.
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
    'currentPlanName': '',
    'overallProgressPercent': 0,
    'totalVersesMemorized': 0,
    'completedJuz': 0,
    'completedSurahs': 0,
    'badges': <String>[],
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class _SeedResult {
  final String teacherUid;
  final String student1Id;
  final String student2Id;
  final String halaqaId;

  const _SeedResult({
    required this.teacherUid,
    required this.student1Id,
    required this.student2Id,
    required this.halaqaId,
  });
}

class _SeedArgs {
  final String teacherUid;
  final String teacherEmail;
  final String teacherPassword;
  final String teacherName;
  final String teacherEmailField;
  final String meetingLink;

  const _SeedArgs({
    required this.teacherUid,
    required this.teacherEmail,
    required this.teacherPassword,
    required this.teacherName,
    required this.teacherEmailField,
    required this.meetingLink,
  });

  factory _SeedArgs.parse(List<String> rawArgs) {
    String opt(String key, {String envKey = '', String fallback = ''}) {
      final prefix = '--$key=';
      for (final a in rawArgs) {
        if (a.startsWith(prefix)) return a.substring(prefix.length);
      }
      if (envKey.isNotEmpty) {
        const defines = <String, String>{
          'SEED_TEACHER_UID': String.fromEnvironment('SEED_TEACHER_UID'),
          'SEED_TEACHER_EMAIL': String.fromEnvironment('SEED_TEACHER_EMAIL'),
          'SEED_TEACHER_PASSWORD': String.fromEnvironment(
            'SEED_TEACHER_PASSWORD',
          ),
          'SEED_TEACHER_NAME': String.fromEnvironment('SEED_TEACHER_NAME'),
          'SEED_MEETING_LINK': String.fromEnvironment('SEED_MEETING_LINK'),
        };
        final v = defines[envKey];
        if (v != null && v.isNotEmpty) return v;
      }
      return fallback;
    }

    final email = opt('teacher-email', envKey: 'SEED_TEACHER_EMAIL');
    return _SeedArgs(
      teacherUid: opt('teacher-uid', envKey: 'SEED_TEACHER_UID'),
      teacherEmail: email,
      teacherPassword: opt('teacher-password', envKey: 'SEED_TEACHER_PASSWORD'),
      teacherName: opt(
        'teacher-name',
        envKey: 'SEED_TEACHER_NAME',
        fallback: _defaultTeacherName,
      ),
      teacherEmailField: email,
      meetingLink: opt(
        'meeting-link',
        envKey: 'SEED_MEETING_LINK',
        fallback: _defaultMeetingLink,
      ),
    );
  }
}
