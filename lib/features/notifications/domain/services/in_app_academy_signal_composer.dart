import '../../../../core/constants/app_constants.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/utils/time_format.dart';
import '../entities/notification_signal.dart';
import '../entities/notification_signal_ids.dart';

/// Delivery-layer mapping: academy facts + resolved observers → in-app messages.
///
/// Owns **how** (wording, type, deterministic card id) for the in-app channel
/// only. Display names may be enriched by the handler — they are not event
/// payload.
class InAppAcademySignalComposer {
  const InAppAcademySignalComposer._();

  static List<NotificationSignal> compose({
    required Iterable<AcademyEvent> events,
    required Map<String, List<String>> observerIdsByEventId,
    Map<String, String> studentNamesById = const {},
  }) {
    final signals = <NotificationSignal>[];

    for (final event in events) {
      final observers = observerIdsByEventId[event.eventId] ?? const <String>[];
      if (observers.isEmpty) continue;

      final type = _type(event);

      for (final observerId in observers) {
        signals.add(
          NotificationSignal(
            id: NotificationSignalIds.forObserver(
              observerId: observerId,
              eventId: event.eventId,
            ),
            audience: observerId,
            title: _title(event, observerId: observerId),
            body: _body(
              event,
              observerId: observerId,
              studentNamesById: studentNamesById,
            ),
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
    HomeworkAssigned() ||
    HomeworkReviewed() ||
    HalaqaActivityPublished() => NotificationTypes.assignment,
  };

  static String _title(AcademyEvent event, {required String observerId}) =>
      switch (event) {
        StudentAbsentRecorded() => 'تم تسجيل غياب',
        StudentAbsenceCorrected() => 'تم تحديث الحضور',
        HomeworkAssigned() => 'تكليف جديد',
        HomeworkReviewed(:final studentId) =>
          observerId == studentId ? 'تم تقييم تسميعك' : 'تم تقييم التسميع',
        HalaqaActivityPublished() => 'مهمة جديدة للحلقة',
      };

  static String _body(
    AcademyEvent event, {
    required String observerId,
    required Map<String, String> studentNamesById,
  }) {
    final name = _studentLabel(event, studentNamesById);

    return switch (event) {
      StudentAbsentRecorded(:final date) =>
        'تم تسجيل غياب $name بتاريخ ${formatDateDmy(date)}',
      StudentAbsenceCorrected(:final date, :final correctedToStatus) =>
        'تم تحديث حالة $name بتاريخ ${formatDateDmy(date)} إلى ${_statusLabel(correctedToStatus)}',
      HomeworkAssigned(
        :final studentId,
        :final newMemorizationRange,
        :final reviewRange,
      ) =>
        _homeworkAssignedBody(
          forSubjectStudent: observerId == studentId,
          studentLabel: name,
          newMemorizationRange: newMemorizationRange,
          reviewRange: reviewRange,
        ),
      HomeworkReviewed(:final studentId, :final grade) => _homeworkReviewedBody(
        forSubjectStudent: observerId == studentId,
        studentLabel: name,
        grade: grade,
      ),
      HalaqaActivityPublished(
        :final studentId,
        :final prompt,
      ) =>
        _activityPublishedBody(
          forSubjectStudent: observerId == studentId,
          studentLabel: name,
          prompt: prompt,
        ),
    };
  }

  /// Preserve legacy student wording; parents get a child-scoped fact line.
  static String _homeworkAssignedBody({
    required bool forSubjectStudent,
    required String studentLabel,
    required String newMemorizationRange,
    required String reviewRange,
  }) {
    final rangeHint = newMemorizationRange.trim().isNotEmpty
        ? newMemorizationRange.trim()
        : reviewRange.trim();

    if (forSubjectStudent) {
      return rangeHint.isEmpty
          ? 'لديك تكليف جديد — افتح واجباتي'
          : 'تكليف جديد: $rangeHint — افتح واجباتي';
    }

    if (rangeHint.isEmpty) {
      return 'تم تعيين تكليف جديد لـ $studentLabel';
    }
    return 'تم تعيين تكليف لـ $studentLabel: $rangeHint';
  }

  static String _homeworkReviewedBody({
    required bool forSubjectStudent,
    required String studentLabel,
    required String? grade,
  }) {
    if (forSubjectStudent) {
      return 'راجع صفحة التقييمات لمعرفة الدرجة والملاحظات';
    }
    final trimmed = grade?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'تم تقييم تسميع $studentLabel';
    }
    return 'تم تقييم تسميع $studentLabel: $trimmed';
  }

  static String _activityPublishedBody({
    required bool forSubjectStudent,
    required String studentLabel,
    required String prompt,
  }) {
    final preview = prompt.trim();
    final clipped = preview.length > 60
        ? '${preview.substring(0, 60)}…'
        : preview;
    if (forSubjectStudent) {
      return clipped.isEmpty
          ? 'مهمة جديدة من معلم الحلقة — افتح أنشطة الحلقة'
          : 'مهمة جديدة: $clipped';
    }
    return clipped.isEmpty
        ? 'مهمة جديدة لـ $studentLabel'
        : 'مهمة جديدة لـ $studentLabel: $clipped';
  }

  static String _statusLabel(String status) => switch (status) {
    AttendancePolicy.statusLate => 'متأخر',
    _ => 'حاضر',
  };

  static String _studentLabel(
    AcademyEvent event,
    Map<String, String> studentNamesById,
  ) {
    final fromEvent = switch (event) {
      StudentAbsentRecorded(:final studentName) => studentName,
      StudentAbsenceCorrected(:final studentName) => studentName,
      HomeworkAssigned() ||
      HomeworkReviewed() ||
      HalaqaActivityPublished() =>
        studentNamesById[event.studentId] ?? '',
    };
    final trimmed = fromEvent.trim();
    return trimmed.isEmpty ? 'الطالب' : trimmed;
  }
}
