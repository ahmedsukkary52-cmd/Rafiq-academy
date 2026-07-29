import '../../../../core/constants/app_constants.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/utils/time_format.dart';
import '../entities/notification_signal.dart';
import '../entities/notification_signal_ids.dart';

/// Delivery-layer mapping: academy facts + resolved observers → in-app messages.
///
/// Owns **how** (wording, type, deterministic card id) for the in-app channel
/// only. Whether an event exists is academy-domain; who should know is the
/// observer layer.
class InAppAcademySignalComposer {
  const InAppAcademySignalComposer._();

  static List<NotificationSignal> compose({
    required Iterable<AcademyEvent> events,
    required Map<String, List<String>> observerIdsByEventId,
  }) {
    final signals = <NotificationSignal>[];

    for (final event in events) {
      final observers = observerIdsByEventId[event.eventId] ?? const <String>[];
      if (observers.isEmpty) continue;

      final title = _title(event);
      final body = _body(event);
      final type = _type(event);

      for (final observerId in observers) {
        signals.add(
          NotificationSignal(
            id: NotificationSignalIds.forObserver(
              observerId: observerId,
              eventId: event.eventId,
            ),
            audience: observerId,
            title: title,
            body: body,
            type: type,
          ),
        );
      }
    }

    return signals;
  }

  static String _type(AcademyEvent event) => switch (event) {
    StudentAbsentRecorded() ||
    StudentAbsenceCorrected() => NotificationTypes.attendance,
    HomeworkAssigned() || HomeworkReviewed() => NotificationTypes.assignment,
  };

  static String _title(AcademyEvent event) => switch (event) {
    StudentAbsentRecorded() => 'تم تسجيل غياب',
    StudentAbsenceCorrected() => 'تم تحديث الحضور',
    HomeworkAssigned() => 'تكليف جديد',
    HomeworkReviewed() => 'تم تقييم التسميع',
  };

  static String _body(AcademyEvent event) {
    final name = _studentLabel(event);

    return switch (event) {
      StudentAbsentRecorded(:final date) =>
        'تم تسجيل غياب $name بتاريخ ${formatDateDmy(date)}',
      StudentAbsenceCorrected(:final date, :final correctedToStatus) =>
        'تم تحديث حالة $name بتاريخ ${formatDateDmy(date)} إلى ${_statusLabel(correctedToStatus)}',
      HomeworkAssigned(:final newMemorizationRange, :final reviewRange) =>
        _homeworkAssignedBody(
          name: name,
          newMemorizationRange: newMemorizationRange,
          reviewRange: reviewRange,
        ),
      HomeworkReviewed(:final grade) =>
        grade == null || grade.trim().isEmpty
            ? 'تم تقييم تسميع $name'
            : 'تم تقييم تسميع $name: ${grade.trim()}',
    };
  }

  static String _homeworkAssignedBody({
    required String name,
    required String newMemorizationRange,
    required String reviewRange,
  }) {
    final rangeHint = newMemorizationRange.trim().isNotEmpty
        ? newMemorizationRange.trim()
        : reviewRange.trim();
    if (rangeHint.isEmpty) {
      return 'تم تعيين تكليف جديد لـ $name';
    }
    return 'تم تعيين تكليف لـ $name: $rangeHint';
  }

  static String _statusLabel(String status) => switch (status) {
    AttendancePolicy.statusLate => 'متأخر',
    _ => 'حاضر',
  };

  static String _studentLabel(AcademyEvent event) {
    final name = switch (event) {
      StudentAbsentRecorded(:final studentName) => studentName,
      StudentAbsenceCorrected(:final studentName) => studentName,
      HomeworkAssigned(:final studentName) => studentName,
      HomeworkReviewed(:final studentName) => studentName,
    };
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'الطالب' : trimmed;
  }
}
