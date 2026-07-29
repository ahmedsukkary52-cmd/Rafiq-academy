import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/supervisor/presentation/escalation/supervisor_fact_provenance.dart';
import 'package:rafiq_academy/shared/domain/halaqa_day_readiness.dart';

void main() {
  group('SupervisorFactProvenance (Rule 7)', () {
    test('every gap kind has facts + owning workflow + resolving action', () {
      for (final kind in HalaqaDayGapKind.values) {
        final p = SupervisorFactProvenance.forGapKind(kind, quantity: 2);
        expect(p.academyFacts, isNotEmpty, reason: '$kind facts');
        expect(p.owningWorkflow, isNotEmpty, reason: '$kind owner');
        expect(p.isResolvable, isTrue, reason: '$kind resolvable');
        expect(p.resolvingAction, isNotEmpty);
        // Must cite W1–W5 lineage, not invent a supervisor rule id.
        expect(
          p.academyFacts.contains('W1') ||
              p.academyFacts.contains('W2') ||
              p.academyFacts.contains('W3'),
          isTrue,
          reason: '$kind must cite W1–W5 facts',
        );
      }
    });

    test(
      'complete and no-session are explainable without resolving actions',
      () {
        expect(SupervisorFactProvenance.complete.academyFacts, isNotEmpty);
        expect(SupervisorFactProvenance.complete.owningWorkflow, isNotEmpty);
        expect(SupervisorFactProvenance.complete.isResolvable, isFalse);

        expect(
          SupervisorFactProvenance.noSessionToday.academyFacts,
          isNotEmpty,
        );
        expect(
          SupervisorFactProvenance.noSessionToday.owningWorkflow,
          isNotEmpty,
        );
        expect(SupervisorFactProvenance.noSessionToday.isResolvable, isFalse);
      },
    );

    test('forGap delegates to gap kind without new readiness math', () {
      const gap = HalaqaDayGap(
        kind: HalaqaDayGapKind.reviewsPending,
        quantity: 3,
      );
      final p = SupervisorFactProvenance.forGap(gap);
      expect(p.academyFacts, contains('3'));
      expect(p.resolvingAction, contains('المعلم'));
    });
  });
}
