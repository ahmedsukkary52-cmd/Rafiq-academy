import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/analytics/domain/analytics_cta_navigation.dart';
import 'package:rafiq_academy/features/analytics/domain/analytics_recitation_honesty.dart';
import 'package:rafiq_academy/features/analytics/domain/entities/analytics_entities.dart';

void main() {
  group('AnalyticsCtaNavigation (Phase 2)', () {
    test('evaluationsPath targets existing Evaluations route + studentId', () {
      expect(
        AnalyticsCtaNavigation.evaluationsPath(halaqaId: 'h1', studentId: 's1'),
        '/teacher/halaqa/h1/evaluations?studentId=s1',
      );
      expect(
        AnalyticsCtaNavigation.evaluationsPath(halaqaId: 'h1', studentId: ''),
        '/teacher/halaqa/h1/evaluations',
      );
    });

    test('allowsStudentContact is teacher↔student only — never parent', () {
      expect(
        AnalyticsCtaNavigation.allowsStudentContact(
          teacherRole: AppRoles.teacher,
          peerRole: AppRoles.student,
        ),
        isTrue,
      );
      expect(
        AnalyticsCtaNavigation.allowsStudentContact(
          teacherRole: AppRoles.teacher,
          peerRole: AppRoles.parent,
        ),
        isFalse,
      );
      expect(
        AnalyticsCtaNavigation.allowsStudentContact(
          teacherRole: AppRoles.teacher,
          peerRole: AppRoles.supervisor,
        ),
        isFalse,
      );
    });

    test('at-risk CTA maps by reason — not both actions on every student', () {
      expect(
        AnalyticsCtaNavigation.atRiskActionLabel(RiskReason.repeatedAbsence),
        'تواصل',
      );
      expect(
        AnalyticsCtaNavigation.atRiskActionIsEvaluate(
          RiskReason.repeatedAbsence,
        ),
        isFalse,
      );
      expect(
        AnalyticsCtaNavigation.atRiskActionLabel(RiskReason.noRecentEvaluation),
        'تقييم',
      );
      expect(
        AnalyticsCtaNavigation.atRiskActionIsEvaluate(
          RiskReason.noRecentEvaluation,
        ),
        isTrue,
      );
      expect(
        AnalyticsCtaNavigation.atRiskActionLabel(RiskReason.lowPerformance),
        'تواصل',
      );
    });
  });

  group('Index inventory (Phase 2)', () {
    test('marks recitationRecords(halaqaId, date) as inventoried in repo', () {
      expect(AnalyticsFirestoreIndexInventory.inventoriedInRepo, isTrue);
      expect(AnalyticsFirestoreIndexInventory.requiredCompositeFields, [
        'halaqaId',
        'date',
      ]);
    });
  });
}
