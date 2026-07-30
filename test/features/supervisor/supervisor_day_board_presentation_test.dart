import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/router/supervisor_escalation_paths.dart';
import 'package:rafiq_academy/features/supervisor/domain/read_models/supervisor_day_board.dart';
import 'package:rafiq_academy/features/supervisor/presentation/escalation/supervisor_escalation_guidance.dart';
import 'package:rafiq_academy/features/supervisor/presentation/widgets/supervisor_day_board_section.dart';
import 'package:rafiq_academy/shared/domain/halaqa_day_readiness.dart';

SupervisorDayBoardItem _item({
  required String id,
  required bool complete,
  DateTime? startAt,
  String teacherName = 'أ. أحمد',
}) {
  return SupervisorDayBoardItem(
    halaqaId: id,
    halaqaName: 'حلقة $id',
    teacherId: 't1',
    teacherDisplayName: teacherName,
    startAt: startAt ?? DateTime(2024, 6, 3, 9),
    readiness: complete
        ? HalaqaDayReadiness.complete
        : const HalaqaDayReadiness(
            gaps: [HalaqaDayGap(kind: HalaqaDayGapKind.homeworkPending)],
          ),
  );
}

void main() {
  group('exceptionFirstItems (presentation)', () {
    test('surfaces exceptions before healthy without changing readiness', () {
      final ordered = exceptionFirstItems([
        _item(
          id: 'healthy-early',
          complete: true,
          startAt: DateTime(2024, 6, 3, 8),
        ),
        _item(
          id: 'exception',
          complete: false,
          startAt: DateTime(2024, 6, 3, 10),
        ),
        _item(
          id: 'healthy-late',
          complete: true,
          startAt: DateTime(2024, 6, 3, 11),
        ),
      ]);

      expect(ordered.map((i) => i.halaqaId).toList(), [
        'exception',
        'healthy-early',
        'healthy-late',
      ]);
    });
  });

  group('explainSupervisorGap (Rule 4 presentation)', () {
    test('explains what and why from gap facts', () {
      expect(
        explainSupervisorGap(
          const HalaqaDayGap(kind: HalaqaDayGapKind.attendanceIncomplete),
        ),
        'لم يُسجَّل الحضور بعد.',
      );
      expect(
        explainSupervisorGap(
          const HalaqaDayGap(kind: HalaqaDayGapKind.homeworkPending),
        ),
        'لم يُعيَّن واجب اليوم.',
      );
      expect(
        explainSupervisorGap(
          const HalaqaDayGap(
            kind: HalaqaDayGapKind.reviewsPending,
            quantity: 3,
          ),
        ),
        '3 تسميعات لا تزال بانتظار المراجعة.',
      );
    });
  });

  group('supervisorEscalationRoute (D-W6-1)', () {
    test('only targets existing teacher-owned workflows', () {
      expect(
        supervisorEscalationRoute(HalaqaDayGapKind.attendanceIncomplete, 'h1'),
        '/teacher/attendance/h1',
      );
      expect(
        supervisorEscalationRoute(HalaqaDayGapKind.homeworkPending, 'h1'),
        '/teacher/halaqa/h1?assign=1',
      );
      expect(
        supervisorEscalationRoute(HalaqaDayGapKind.reviewsPending, 'h1'),
        '/teacher/halaqa/h1/evaluations',
      );
    });
  });

  group('SupervisorEscalationGuidance (Rule 6)', () {
    test('answers who / why / where without transferring ownership', () {
      final item = _item(id: 'h1', complete: false);
      final guidance = SupervisorEscalationGuidance.fromGap(
        item: item,
        gap: const HalaqaDayGap(kind: HalaqaDayGapKind.homeworkPending),
      );

      expect(guidance.ownerName, 'أ. أحمد');
      expect(guidance.halaqaName, 'حلقة h1');
      expect(guidance.why, 'لم يُعيَّن واجب اليوم.');
      expect(guidance.whereLabel, contains('المعلم'));
      expect(guidance.route, startsWith('/teacher/'));
      expect(guidance.canNavigate, isTrue);
    });

    test('permission fallback keeps facts and disables navigation CTA', () {
      final item = _item(id: 'h1', complete: false);
      final guidance = SupervisorEscalationGuidance.fromGap(
        item: item,
        gap: const HalaqaDayGap(
          kind: HalaqaDayGapKind.attendanceIncomplete,
          quantity: 2,
        ),
        navigationAllowed: false,
      );

      expect(guidance.canNavigate, isFalse);
      expect(guidance.ownerName, isNotEmpty);
      expect(guidance.halaqaName, isNotEmpty);
      expect(guidance.why, isNotEmpty);
      expect(
        SupervisorEscalationPaths.isAllowed('/supervisor/fake-write'),
        isFalse,
      );
    });
  });
}
