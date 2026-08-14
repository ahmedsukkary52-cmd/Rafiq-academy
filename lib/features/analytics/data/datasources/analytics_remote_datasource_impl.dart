import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/domain/student_at_risk_policy.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../domain/analytics_recitation_honesty.dart';
import '../../domain/entities/analytics_entities.dart';
import 'analytics_remote_datasource.dart';

@LazySingleton(as: AnalyticsRemoteDatasource)
class AnalyticsRemoteDatasourceImpl implements AnalyticsRemoteDatasource {
  final FirebaseFirestore firestore;

  const AnalyticsRemoteDatasourceImpl({required this.firestore});

  @override
  Future<HalaqaAnalyticsEntity> getHalaqaAnalytics({
    required String halaqaId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      // نجيب الحلقة لمعرفة عدد الطلاب أولاً
      final halaqaDoc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .get();

      final halaqaData = halaqaDoc.data() as Map<String, dynamic>;
      final studentIds = List<String>.from(halaqaData['studentIds'] ?? []);
      final totalStudents = studentIds.length;

      if (totalStudents == 0) {
        return HalaqaAnalyticsEntity(
          halaqaId: halaqaId,
          averagePerformancePercent: 0,
          attendancePercent: 0,
          totalStudents: 0,
          performanceDistribution: const {},
          weeklyAttendance: const {},
        );
      }

      // جلب سجلات التسميع والحضور بالتوازي
      // Requires composite index: recitationRecords (halaqaId ASC, date ASC)
      // — see AnalyticsFirestoreIndexInventory (Phase 1: inventory only).
      final results = await Future.wait([
        firestore
            .collection(FirestoreCollections.recitationRecords)
            .where('halaqaId', isEqualTo: halaqaId)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
            .where('date', isLessThan: Timestamp.fromDate(to))
            .get(),
        firestore
            .collection(FirestoreCollections.attendanceRecords)
            .where('halaqaId', isEqualTo: halaqaId)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
            .where('date', isLessThan: Timestamp.fromDate(to))
            .get(),
      ]);

      final recitationDocs = results[0].docs;
      final attendanceDocs = results[1].docs;

      final performance = AnalyticsRecitationHonesty.aggregatePerformance(
        recitationDocs.map(_toRecitationRef),
      );

      // حساب نسبة الحضور (D1: late counts as attended; one mark per student/day)
      // Attendance SSOT unchanged — no honesty filter on attendance.
      final statuses = AttendancePolicy.uniqueDayStatuses(
        attendanceDocs.map((d) {
          final data = d.data();
          final rawDate = data['date'];
          final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
          return AttendanceMarkRef(
            id: d.id,
            halaqaId: halaqaId,
            studentId: (data['studentId'] as String?) ?? '',
            date: date,
            status: data['status'] as String?,
          );
        }),
      );
      final attendancePercent = AttendancePolicy.attendancePercentFromStatuses(
        statuses,
      );

      // حساب الحضور الأسبوعي (آخر 7 أيام تقويمية فقط)
      final weeklyAttendance = _calculateWeeklyAttendance(
        attendanceDocs,
        halaqaId: halaqaId,
      );

      return HalaqaAnalyticsEntity(
        halaqaId: halaqaId,
        averagePerformancePercent: performance.averagePercent,
        attendancePercent: attendancePercent,
        totalStudents: totalStudents,
        performanceDistribution: performance.distribution,
        weeklyAttendance: weeklyAttendance,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AtRiskStudentEntity>> getAtRiskStudents(String halaqaId) async {
    try {
      final now = DateTime.now();
      final windowStart = now.subtract(
        const Duration(days: StudentAtRiskPolicy.windowDays),
      );

      final results = await Future.wait([
        // كل علامات الحضور لآخر أسبوعين (ثم نفلتر الغياب بعد إزالة التكرار)
        firestore
            .collection(FirestoreCollections.attendanceRecords)
            .where('halaqaId', isEqualTo: halaqaId)
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart),
            )
            .get(),
        // تسميعات النافذة — التقييم الصادق يُصفّى عبر AnalyticsRecitationHonesty
        firestore
            .collection(FirestoreCollections.recitationRecords)
            .where('halaqaId', isEqualTo: halaqaId)
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart),
            )
            .get(),
      ]);

      final attendanceDocs = results[0].docs;
      final recitationDocs = results[1].docs;

      final atRiskMap = <String, AtRiskStudentEntity>{};

      final marksByStudent = <String, List<AttendanceMarkRef>>{};
      for (final doc in attendanceDocs) {
        final data = doc.data();
        final studentId = (data['studentId'] as String?) ?? '';
        if (studentId.isEmpty) continue;
        final rawDate = data['date'];
        final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
        marksByStudent
            .putIfAbsent(studentId, () => [])
            .add(
              AttendanceMarkRef(
                id: doc.id,
                halaqaId: halaqaId,
                studentId: studentId,
                date: date,
                status: data['status'] as String?,
              ),
            );
      }

      final evaluatedStudentIds =
          AnalyticsRecitationHonesty.evaluatedStudentIds(
            recitationDocs.map(_toRecitationRef),
          );

      final halaqaDoc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .get();
      final studentIds = List<String>.from(
        (halaqaDoc.data() as Map<String, dynamic>)['studentIds'] ?? [],
      );

      for (final studentId in studentIds) {
        // Thresholds / lowPerformance unchanged — only evaluation honesty input.
        final signal = StudentAtRiskPolicy.evaluate(
          marksInWindow: marksByStudent[studentId] ?? const [],
          hasEvaluationInWindow: evaluatedStudentIds.contains(studentId),
        );
        if (signal == null) continue;

        final userDoc = await firestore
            .collection(FirestoreCollections.users)
            .doc(studentId)
            .get();
        final userData = userDoc.data() ?? {};
        final absences = AttendancePolicy.countAbsent(
          AttendancePolicy.uniqueDayStatuses(
            marksByStudent[studentId] ?? const [],
          ),
        );

        atRiskMap[studentId] = AtRiskStudentEntity(
          studentId: studentId,
          studentName: userData['name'] as String? ?? '',
          profileImageUrl: userData['profileImageUrl'] as String?,
          reason: switch (signal) {
            RiskSignal.repeatedAbsence => RiskReason.repeatedAbsence,
            RiskSignal.noRecentEvaluation => RiskReason.noRecentEvaluation,
            RiskSignal.lowPerformance => RiskReason.lowPerformance,
          },
          detail: switch (signal) {
            RiskSignal.repeatedAbsence =>
              '$absences غيابات خلال آخر أسبوعين',
            RiskSignal.noRecentEvaluation => 'لم يُقيَّم منذ أسبوعين',
            RiskSignal.lowPerformance => 'أداء منخفض',
          },
        );
      }

      return atRiskMap.values.toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<TopStudentEntity>> getTopStudents({
    required String halaqaId,
    int limit = 5,
  }) async {
    try {
      final oneMonth = DateTime.now().subtract(const Duration(days: 30));

      final snap = await firestore
          .collection(FirestoreCollections.recitationRecords)
          .where('halaqaId', isEqualTo: halaqaId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(oneMonth))
          .get();

      final ranked = AnalyticsRecitationHonesty.rankTopStudents(
        snap.docs.map(_toRecitationRef),
        limit: limit,
      );

      return ranked.indexed.map((entry) {
        final rank = entry.$1 + 1;
        final score = entry.$2;
        return TopStudentEntity(
          studentId: score.studentId,
          studentName: score.studentName,
          profileImageUrl: null,
          performancePercent: score.performancePercent,
          rank: rank,
        );
      }).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  AnalyticsRecitationRef _toRecitationRef(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AnalyticsRecitationRef(
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String?,
      grade: data['grade'] as String?,
      reviewStatus: data['reviewStatus'] as String?,
    );
  }

  /// حساب نسبة الحضور لكل يوم في آخر 7 أيام تقويمية
  Map<String, double> _calculateWeeklyAttendance(
    List<QueryDocumentSnapshot> docs, {
    required String halaqaId,
  }) {
    final dayNames = ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'];
    final today = AttendancePolicy.dayStart(DateTime.now());
    final weekStart = today.subtract(const Duration(days: 6));

    final marksByWeekday = <int, List<AttendanceMarkRef>>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['date'] as Timestamp;
      final date = timestamp.toDate();
      final day = AttendancePolicy.dayStart(date);
      if (day.isBefore(weekStart) || day.isAfter(today)) continue;

      final weekday = day.weekday % 7; // 0=أحد
      marksByWeekday
          .putIfAbsent(weekday, () => [])
          .add(
            AttendanceMarkRef(
              id: doc.id,
              halaqaId: halaqaId,
              studentId: (data['studentId'] as String?) ?? '',
              date: day,
              status: data['status'] as String?,
            ),
          );
    }

    return {
      for (int i = 0; i < 7; i++)
        dayNames[i]: AttendancePolicy.attendancePercentFromStatuses(
          AttendancePolicy.uniqueDayStatuses(marksByWeekday[i] ?? const []),
        ),
    };
  }
}
