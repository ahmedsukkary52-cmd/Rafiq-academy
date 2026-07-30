import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/absence_request.dart';
import 'package:rafiq_academy/shared/domain/absence_request_projection.dart';

AbsenceRequestEntity _request(AbsenceRequestStatus status) =>
    AbsenceRequestEntity(
      id: '1',
      studentId: 's1',
      halaqaId: 'h1',
      requestedBy: 'p1',
      date: DateTime(2024, 6, 3),
      reason: 'سبب',
      status: status,
      reviewedBy: status == AbsenceRequestStatus.pending ? null : 't1',
    );

void main() {
  group('AbsenceRequestProjection (W7 Rule 2 / H4 shared)', () {
    test('status labels map existing enum only', () {
      expect(
        AbsenceRequestProjection.statusLabel(AbsenceRequestStatus.pending),
        'قيد المراجعة',
      );
      expect(
        AbsenceRequestProjection.statusLabel(AbsenceRequestStatus.approved),
        'مقبول',
      );
      expect(
        AbsenceRequestProjection.statusLabel(AbsenceRequestStatus.rejected),
        'مرفوض',
      );
    });

    test('isDecided derives from request status field only', () {
      expect(
        AbsenceRequestProjection.isDecided(
          _request(AbsenceRequestStatus.pending),
        ),
        isFalse,
      );
      expect(
        AbsenceRequestProjection.isDecided(
          _request(AbsenceRequestStatus.approved),
        ),
        isTrue,
      );
      expect(
        AbsenceRequestProjection.isDecided(
          _request(AbsenceRequestStatus.rejected),
        ),
        isTrue,
      );
    });
  });
}
