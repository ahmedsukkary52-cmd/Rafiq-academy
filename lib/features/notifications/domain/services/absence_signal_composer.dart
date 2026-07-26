import '../../../../core/constants/app_constants.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/utils/time_format.dart';
import '../entities/notification_signal.dart';

/// Pure mapping: attendance academy events + recipients → in-app messages.
///
/// This is presentation of an event, not a business rule: it decides wording
/// and per-recipient message identity only. Whether an event exists at all is
/// decided by the attendance transition projector.
class AbsenceSignalComposer {
  const AbsenceSignalComposer._();

  static List<NotificationSignal> compose({
    required Iterable<AcademyEvent> events,
    required Map<String, List<String>> parentIdsByStudentId,
  }) {
    final signals = <NotificationSignal>[];

    for (final event in events) {
      final studentId = studentIdOf(event);
      final recipients = parentIdsByStudentId[studentId] ?? const <String>[];
      if (recipients.isEmpty) continue;

      final title = _title(event);
      final body = _body(event);

      for (final parentId in recipients) {
        signals.add(
          NotificationSignal(
            id: AcademyEventIds.inAppDeliveryId(
              parentId: parentId,
              eventId: event.eventId,
            ),
            audience: parentId,
            title: title,
            body: body,
            type: NotificationTypes.attendance,
          ),
        );
      }
    }

    return signals;
  }

  /// Student each attendance event is about. Exhaustive over [AcademyEvent],
  /// so a future event kind cannot be silently mis-addressed.
  static String studentIdOf(AcademyEvent event) => switch (event) {
    StudentAbsentRecorded() => event.studentId,
    StudentAbsenceCorrected() => event.studentId,
  };

  static String _title(AcademyEvent event) => switch (event) {
    StudentAbsentRecorded() => 'تم تسجيل غياب',
    StudentAbsenceCorrected() => 'تم تحديث الحضور',
  };

  static String _body(AcademyEvent event) {
    final name = _studentLabel(event);
    final date = formatDateDmy(_dateOf(event));

    return switch (event) {
      StudentAbsentRecorded() => 'تم تسجيل غياب $name بتاريخ $date',
      StudentAbsenceCorrected() =>
        'تم تحديث حالة $name بتاريخ $date إلى ${_statusLabel(event.correctedToStatus)}',
    };
  }

  static String _statusLabel(String status) => switch (status) {
    AttendancePolicy.statusLate => 'متأخر',
    _ => 'حاضر',
  };

  static DateTime _dateOf(AcademyEvent event) => switch (event) {
    StudentAbsentRecorded() => event.date,
    StudentAbsenceCorrected() => event.date,
  };

  static String _studentLabel(AcademyEvent event) {
    final name = switch (event) {
      StudentAbsentRecorded() => event.studentName,
      StudentAbsenceCorrected() => event.studentName,
    };
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'الطالب' : trimmed;
  }
}
