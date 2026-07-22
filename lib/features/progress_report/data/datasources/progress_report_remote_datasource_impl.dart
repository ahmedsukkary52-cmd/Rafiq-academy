import 'package:injectable/injectable.dart';

import '../../domain/entities/progress_report_entity.dart';
import 'progress_report_remote_datasource.dart';

/// TODO: ربط بـ Firestore / analytics للحضور والحفظ الأسبوعي وملاحظات المعلم.
/// دقة الحفظ تُستبدل في الـ Bloc من `overallProgressPercent` في بروفايل الطالب.
@LazySingleton(as: ProgressReportRemoteDatasource)
class ProgressReportRemoteDatasourceImpl
    implements ProgressReportRemoteDatasource {
  @override
  Future<ProgressReportEntity> getReport({required String studentId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const ProgressReportEntity(
      memorizationAccuracyPercent: 0,
      // يُستبدل من البروفايل
      attendedSessions: 21,
      monthlyAttendancePercent: 95,
      attendanceDays: 21,
      absenceDays: 1,
      weeklyVersesPerDay: [3, 4, 12, 5, 6, 11, 4],
      teacherNotes:
          'أحمد طالب مجتهد ومنتظم، تحسن نطقه كثيراً هذا الشهر. أنصح بمزيد من التركيز على أحكام المدود.',
    );
  }
}
