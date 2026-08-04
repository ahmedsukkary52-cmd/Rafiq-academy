import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/domain/student_at_risk_policy.dart';
import '../../../../shared/utils/attendance_policy.dart';
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

      // حساب توزيع الأداء من التسميعات
      final gradeCount = <String, int>{
        RecitationGrades.excellent: 0,
        RecitationGrades.veryGood: 0,
        RecitationGrades.good: 0,
        'يحتاج تحسين': 0,
      };

      for (final doc in recitationDocs) {
        final grade = (doc.data())['grade'] as String? ?? '';
        if (gradeCount.containsKey(grade)) {
          gradeCount[grade] = (gradeCount[grade] ?? 0) + 1;
        }
      }

      // حساب متوسط الأداء: ممتاز=100، جيد جداً=80، جيد=60، يحتاج=40
      final gradeWeights = {
        RecitationGrades.excellent: 100.0,
        RecitationGrades.veryGood: 80.0,
        RecitationGrades.good: 60.0,
        'يحتاج تحسين': 40.0,
      };

      double totalScore = 0;
      int totalGrades = 0;
      for (final entry in gradeCount.entries) {
        totalScore += (gradeWeights[entry.key] ?? 0) * entry.value;
        totalGrades += entry.value;
      }

      final avgPerformance = totalGrades > 0 ? totalScore / totalGrades : 0.0;

      // حساب نسبة الحضور (D1: late counts as attended; one mark per student/day)
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
        averagePerformancePercent: avgPerformance,
        attendancePercent: attendancePercent,
        totalStudents: totalStudents,
        performanceDistribution: gradeCount,
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
        // طلاب مش اتقيّموا من أسبوعين
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

      final evaluatedStudentIds = recitationDocs
          .map((d) => (d.data())['studentId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final halaqaDoc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .get();
      final studentIds = List<String>.from(
        (halaqaDoc.data() as Map<String, dynamic>)['studentIds'] ?? [],
      );

      for (final studentId in studentIds) {
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

      // تجميع النقاط لكل طالب
      final scoreMap = <String, double>{};
      final countMap = <String, int>{};
      final nameMap = <String, String>{};
      final imageMap = <String, String?>{};

      const weights = {
        'ممتاز': 100.0,
        'جيد جداً': 80.0,
        'جيد': 60.0,
        'يحتاج تحسين': 40.0,
      };

      for (final doc in snap.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String? ?? '';
        final grade = data['grade'] as String? ?? '';
        final name = data['studentName'] as String? ?? '';

        scoreMap[studentId] =
            (scoreMap[studentId] ?? 0) + (weights[grade] ?? 0);
        countMap[studentId] = (countMap[studentId] ?? 0) + 1;
        nameMap[studentId] = name;
      }

      // حساب المتوسط وترتيب الطلاب
      final averages =
          scoreMap.entries
              .map((e) => MapEntry(e.key, e.value / (countMap[e.key] ?? 1)))
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      return averages.take(limit).indexed.map((entry) {
        final rank = entry.$1 + 1;
        final studentId = entry.$2.key;
        final avg = entry.$2.value;
        return TopStudentEntity(
          studentId: studentId,
          studentName: nameMap[studentId] ?? '',
          profileImageUrl: imageMap[studentId],
          performancePercent: avg,
          rank: rank,
        );
      }).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
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
