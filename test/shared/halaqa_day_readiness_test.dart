import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/halaqa_day_readiness.dart';

final _monday = DateTime(2024, 6, 3, 9, 0);
final _mondayDue = DateTime(2024, 6, 3, 23, 59, 59);
final _tuesdayDue = DateTime(2024, 6, 4, 23, 59, 59);

void main() {
  group('HalaqaDayReadinessProjector', () {
    test('all pillars clear → complete (empty gaps)', () {
      final readiness = HalaqaDayReadinessProjector.project(
        rosterStudentIds: const ['s1'],
        markedStudentIds: const ['s1'],
        now: _monday,
        latestAssignmentDueDate: _mondayDue,
        pendingReviewCount: 0,
      );

      expect(readiness, HalaqaDayReadiness.complete);
      expect(readiness.isComplete, isTrue);
      expect(readiness.needsAttention, isFalse);
    });

    test('empty roster → complete (no attendance or homework gap)', () {
      final readiness = HalaqaDayReadinessProjector.project(
        rosterStudentIds: const [],
        markedStudentIds: const [],
        now: _monday,
        latestAssignmentDueDate: null,
        pendingReviewCount: 0,
      );

      expect(readiness.isComplete, isTrue);
    });

    test('attendance incomplete carries unmarked quantity', () {
      final readiness = HalaqaDayReadinessProjector.project(
        rosterStudentIds: const ['s1', 's2', 's3'],
        markedStudentIds: const ['s1'],
        now: _monday,
        latestAssignmentDueDate: _mondayDue,
        pendingReviewCount: 0,
      );

      expect(readiness.gaps, [
        const HalaqaDayGap(
          kind: HalaqaDayGapKind.attendanceIncomplete,
          quantity: 2,
        ),
      ]);
    });

    test('missing / stale homework → homeworkPending without quantity', () {
      final missing = HalaqaDayReadinessProjector.project(
        rosterStudentIds: const ['s1'],
        markedStudentIds: const ['s1'],
        now: _monday,
        latestAssignmentDueDate: null,
        pendingReviewCount: 0,
      );
      final stale = HalaqaDayReadinessProjector.project(
        rosterStudentIds: const ['s1'],
        markedStudentIds: const ['s1'],
        now: _monday,
        latestAssignmentDueDate: _tuesdayDue,
        pendingReviewCount: 0,
      );

      expect(missing.gaps, [
        const HalaqaDayGap(kind: HalaqaDayGapKind.homeworkPending),
      ]);
      expect(stale.gaps, [
        const HalaqaDayGap(kind: HalaqaDayGapKind.homeworkPending),
      ]);
    });

    test('pending reviews carry count for Rule 4 explanations', () {
      final readiness = HalaqaDayReadinessProjector.project(
        rosterStudentIds: const ['s1'],
        markedStudentIds: const ['s1'],
        now: _monday,
        latestAssignmentDueDate: _mondayDue,
        pendingReviewCount: 3,
      );

      expect(readiness.gaps, [
        const HalaqaDayGap(kind: HalaqaDayGapKind.reviewsPending, quantity: 3),
      ]);
    });

    test(
      'all three gaps appear in stable attendance → homework → reviews order',
      () {
        final readiness = HalaqaDayReadinessProjector.project(
          rosterStudentIds: const ['s1', 's2'],
          markedStudentIds: const [],
          now: _monday,
          latestAssignmentDueDate: null,
          pendingReviewCount: 1,
        );

        expect(readiness.gaps.map((g) => g.kind).toList(), [
          HalaqaDayGapKind.attendanceIncomplete,
          HalaqaDayGapKind.homeworkPending,
          HalaqaDayGapKind.reviewsPending,
        ]);
      },
    );

    test('blank roster / mark ids are ignored like AttendancePolicy', () {
      final readiness = HalaqaDayReadinessProjector.project(
        rosterStudentIds: const ['s1', '  ', ''],
        markedStudentIds: const ['s1', ''],
        now: _monday,
        latestAssignmentDueDate: _mondayDue,
        pendingReviewCount: 0,
      );

      expect(readiness.isComplete, isTrue);
    });
  });
}
