import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/parent/domain/parent_household.dart';
import 'package:rafiq_academy/features/parent/presentation/parent_display.dart';
import 'package:rafiq_academy/features/parent/presentation/parent_home_nav.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/shared/domain/student_at_risk_policy.dart';

void main() {
  group('ParentHomeNav', () {
    test('bottom nav has five locked destinations', () {
      expect(ParentHomeNav.labels, [
        'الرئيسية',
        'أبنائي',
        'الرسائل',
        'المدفوعات',
        'الحساب',
      ]);
      expect(ParentHomeNav.labels[ParentHomeNav.storeIndex], 'المدفوعات');
      expect(ParentHomeNav.labels[ParentHomeNav.accountIndex], 'الحساب');
      expect(ParentHomeNav.labels, isNot(contains('الدعم')));
    });
  });

  group('parent display labels', () {
    test('converts western digits to eastern Arabic', () {
      expect(parentEasternDigits('3 أبناء'), '٣ أبناء');
    });

    test('formats missing percent as dash', () {
      expect(parentPercentLabel(null), '—');
      expect(parentPercentLabel(85.4), '٨٥٪');
    });

    test('builds teacher caption without inventing a name', () {
      expect(parentTeacherCaption(''), '');
      expect(parentTeacherCaption('خالد'), 'أ. خالد');
      expect(parentTeacherCaption('أ. فاطمة'), 'أ. فاطمة');
    });

    test('status banner uses real risk or reviewed grade only', () {
      expect(
        parentChildStatusBanner(
          const ParentChildSnapshot(
            studentId: 's1',
            name: 'أحمد',
            isAtRisk: true,
            riskSignal: RiskSignal.repeatedAbsence,
          ),
        ),
        contains('غياب متكرر'),
      );
      expect(
        parentChildStatusBanner(
          const ParentChildSnapshot(
            studentId: 's1',
            name: 'سارة',
            latestReviewedGrade: RecitationGrade.excellent,
          ),
        ),
        'آخر تقييم: ممتاز',
      );
    });

    test('labels household staff as the children teacher or supervisor', () {
      const children = [
        ParentChildSnapshot(
          studentId: 's1',
          name: 'أحمد',
          teacherId: 't1',
          supervisorId: 'sv1',
        ),
        ParentChildSnapshot(
          studentId: 's2',
          name: 'سارة',
          teacherId: 't1',
        ),
      ];
      expect(
        parentStaffRelationCaption(
          role: 'teacher',
          staffUid: 't1',
          children: children,
        ),
        'معلم أحمد · سارة',
      );
      expect(
        parentStaffRelationCaption(
          role: 'supervisor',
          staffUid: 'sv1',
          children: children,
        ),
        'مشرف أحمد',
      );
      expect(
        parentStaffRelationCaption(
          role: 'admin',
          staffUid: 'a1',
          children: children,
        ),
        'إدارة الأكاديمية',
      );
    });
  });
}
