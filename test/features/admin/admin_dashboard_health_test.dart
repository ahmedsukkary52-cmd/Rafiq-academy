import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/domain/entities/complaint_entity.dart';
import 'package:rafiq_academy/features/admin/domain/entities/financial_summary_entity.dart';
import 'package:rafiq_academy/features/admin/domain/entities/registration_request_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_state.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_dashboard_tab.dart';

FinancialSummaryEntity _finance({int overdue = 0, int awaiting = 0}) =>
    FinancialSummaryEntity(
      totalRevenue: 0,
      totalPending: 0,
      totalOverdue: 0,
      paidCount: 0,
      dueCount: 2,
      overdueCount: overdue,
      awaitingReviewCount: awaiting,
    );

ComplaintEntity _complaint(String status) => ComplaintEntity(
  id: 'c-$status',
  senderId: 'p1',
  senderRole: 'parent',
  subject: 's',
  message: 'm',
  status: status,
  createdAt: DateTime(2026, 10, 30),
);

AdminState _loaded({
  FinancialSummaryEntity? finance,
  List<ComplaintEntity> complaints = const [],
  List<RegistrationRequestEntity> requests = const [],
  SectionStatus stats = SectionStatus.loaded,
}) => const AdminState().copyWith(
  statsStatus: stats,
  financialStatus: SectionStatus.loaded,
  complaintsStatus: SectionStatus.loaded,
  registrationStatus: SectionStatus.loaded,
  financialSummary: finance ?? _finance(),
  complaints: complaints,
  registrationRequests: requests,
);

void main() {
  test('normal when nothing needs attention', () {
    final h = adminDashboardHealth(_loaded(), loading: false);
    expect(h.level, AdminHealthLevel.normal);
    expect(h.headline, 'كل شيء على ما يرام اليوم');
  });

  test('loading wins while sections load', () {
    expect(
      adminDashboardHealth(_loaded(), loading: true).level,
      AdminHealthLevel.loading,
    );
  });

  test('a failed section is an error even with warnings present', () {
    final h = adminDashboardHealth(
      _loaded(stats: SectionStatus.error, finance: _finance(overdue: 3)),
      loading: false,
    );
    expect(h.level, AdminHealthLevel.error);
  });

  test('overdue payments and open complaints are warnings', () {
    final h = adminDashboardHealth(
      _loaded(
        finance: _finance(overdue: 2, awaiting: 1),
        complaints: [
          _complaint(ComplaintStatuses.open),
          _complaint(ComplaintStatuses.resolved),
          _complaint(ComplaintStatuses.archived),
        ],
      ),
      loading: false,
    );
    expect(h.level, AdminHealthLevel.warning);
    expect(h.headline, '2 دفعات متأخرة');
    expect(h.detail, '1 شكوى تحتاج متابعة');
  });

  test('registrations and proofs under review are pending, not warnings', () {
    final h = adminDashboardHealth(
      _loaded(
        finance: _finance(awaiting: 3),
        requests: const [RegistrationRequestEntity(studentId: 's1', name: 'أ')],
      ),
      loading: false,
    );
    expect(h.level, AdminHealthLevel.pending);
    expect(h.headline, '1 طلب بانتظار التعيين');
    expect(h.detail, '3 إيصالات قيد مراجعة المشرفين');
  });

  test('resolved / archived complaints are not open', () {
    expect(isOpenComplaintStatus(ComplaintStatuses.open), isTrue);
    expect(isOpenComplaintStatus(ComplaintStatuses.inProgress), isTrue);
    expect(isOpenComplaintStatus(ComplaintStatuses.resolved), isFalse);
    expect(isOpenComplaintStatus(ComplaintStatuses.archived), isFalse);
  });
}
