import 'package:injectable/injectable.dart';

import '../../domain/entities/class_session_entity.dart';
import '../models/class_session_model.dart';
import 'schedule_remote_datasource.dart';

/// TODO: ربط بـ Firestore (مثلاً collection `classSessions` أو جدول الحلقة)
/// حالياً بيانات تجريبية لعرض الـ UI.
@LazySingleton(as: ScheduleRemoteDatasource)
class ScheduleRemoteDatasourceImpl implements ScheduleRemoteDatasource {
  @override
  Future<List<ClassSessionModel>> getWeeklySessions() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 16);
    final todayEnd = DateTime(now.year, now.month, now.day, 17);

    return [
      ClassSessionModel(
        id: 's1',
        title: 'حصة الحفظ اليومية',
        type: ClassSessionType.memorization,
        startAt: todayStart,
        endAt: todayEnd,
        teacherName: 'الشيخ عبدالرحمن محمد',
        status: ClassSessionStatus.live,
        meetingLink: 'https://zoom.us/j/example',
        topic: 'سورة الملك',
      ),
      ClassSessionModel(
        id: 's2',
        title: 'حصة المراجعة',
        type: ClassSessionType.review,
        startAt: todayStart.add(const Duration(days: 1)),
        endAt: todayEnd.add(const Duration(days: 1)),
        teacherName: 'الشيخ عبدالرحمن',
        status: ClassSessionStatus.upcoming,
        meetingLink: '',
      ),
      ClassSessionModel(
        id: 's3',
        title: 'حصة التجويد',
        type: ClassSessionType.tajweed,
        startAt: todayStart.add(const Duration(days: 3)),
        endAt: todayEnd.add(const Duration(days: 3)),
        teacherName: 'الشيخة سارة',
        status: ClassSessionStatus.upcoming,
        meetingLink: '',
      ),
      ClassSessionModel(
        id: 's4',
        title: 'حصة الحفظ اليومية',
        type: ClassSessionType.memorization,
        startAt: todayStart.subtract(const Duration(days: 1)),
        endAt: todayEnd.subtract(const Duration(days: 1)),
        teacherName: 'الشيخ عبدالرحمن محمد',
        status: ClassSessionStatus.ended,
        meetingLink: '',
      ),
    ];
  }
}
