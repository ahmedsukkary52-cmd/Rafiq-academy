import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/parent/domain/parent_household.dart';
import 'package:rafiq_academy/shared/domain/student_at_risk_policy.dart';

void main() {
  group('ParentHouseholdAssembler', () {
    const child = ParentChildSnapshot(
      studentId: 's1',
      name: 'أحمد',
      todayAttendanceStatus: 'present',
      isAtRisk: true,
      riskSignal: RiskSignal.repeatedAbsence,
      attendancePercentInWindow: 80,
    );

    test('summarize uses only existing aggregations', () {
      final summary = ParentHouseholdAssembler.summarize(
        children: const [child],
        payments: [
          PaymentEntity(
            id: 'p1',
            studentId: 's1',
            parentId: 'parent',
            amount: 100,
            dueDate: DateTime(2026, 1, 1),
            status: PaymentStatus.overdue,
          ),
        ],
      );

      expect(summary.childrenCount, 1);
      expect(summary.presentTodayCount, 1);
      expect(summary.atRiskCount, 1);
      expect(summary.overduePaymentsCount, 1);
      expect(summary.averageAttendancePercent, 80);
    });

    test('overdue payment alert disappears when payment is paid', () {
      final overdue = ParentHouseholdAssembler.alerts(
        children: const [child],
        payments: [
          PaymentEntity(
            id: 'p1',
            studentId: 's1',
            parentId: 'parent',
            amount: 100,
            dueDate: DateTime(2026, 1, 1),
            status: PaymentStatus.overdue,
          ),
        ],
      );
      expect(
        overdue.any((a) => a.kind == ParentAlertKind.overduePayment),
        isTrue,
      );

      final paid = ParentHouseholdAssembler.alerts(
        children: const [child],
        payments: [
          PaymentEntity(
            id: 'p1',
            studentId: 's1',
            parentId: 'parent',
            amount: 100,
            dueDate: DateTime(2026, 1, 1),
            status: PaymentStatus.paid,
          ),
        ],
      );
      expect(
        paid.any((a) => a.kind == ParentAlertKind.overduePayment),
        isFalse,
      );
    });

    test('attaches worst payment status per child', () {
      final hydrated = ParentHouseholdAssembler.withPayments(
        children: const [child],
        payments: [
          PaymentEntity(
            id: 'a',
            studentId: 's1',
            parentId: 'parent',
            amount: 50,
            dueDate: DateTime(2026, 1, 1),
            status: PaymentStatus.paid,
          ),
          PaymentEntity(
            id: 'b',
            studentId: 's1',
            parentId: 'parent',
            amount: 50,
            dueDate: DateTime(2026, 2, 1),
            status: PaymentStatus.overdue,
          ),
        ],
      );
      expect(hydrated.single.paymentStatus, PaymentStatus.overdue);
    });
  });
}
