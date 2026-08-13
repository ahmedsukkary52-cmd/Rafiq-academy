import 'academy_event.dart';

/// Channel-agnostic description of who should know about an [AcademyEvent].
///
/// This is the **observer layer** intent — not a delivery address and not part
/// of the event itself. Resolvers expand specs into concrete user ids (or,
/// later, system subscribers). Adding Supervisor / Analytics / Audit means
/// adding specs + resolver support — not changing emitters.
sealed class AcademyObserverSpec {
  const AcademyObserverSpec();
}

/// The student the fact is about.
class SubjectStudentObserver extends AcademyObserverSpec {
  final String studentId;

  const SubjectStudentObserver(this.studentId);
}

/// Every parent profile linked to the student.
class LinkedParentsObserver extends AcademyObserverSpec {
  final String studentId;

  const LinkedParentsObserver(this.studentId);
}

// Future specs (not wired in W5 Pre-Slice), e.g.:
// class HalaqaSupervisorObserver extends AcademyObserverSpec { … }
// class RoleAudienceObserver extends AcademyObserverSpec { … }
// class AuditLogObserver extends AcademyObserverSpec { … }

/// Pure policy: which observer specs apply to each academy fact.
///
/// Owns **who should know**, not how they are informed.
class AcademyEventObservation {
  const AcademyEventObservation._();

  static List<AcademyObserverSpec> specsFor(AcademyEvent event) =>
      switch (event) {
        StudentAbsentRecorded(:final studentId) ||
        StudentAbsenceCorrected(
          :final studentId,
        ) => [LinkedParentsObserver(studentId)],
        HomeworkAssigned(:final studentId) ||
        HomeworkReviewed(:final studentId) ||
        HalaqaActivityPublished(:final studentId) => [
          SubjectStudentObserver(studentId),
          LinkedParentsObserver(studentId),
        ],
      };
}
