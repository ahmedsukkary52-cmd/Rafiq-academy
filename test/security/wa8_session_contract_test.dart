import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/data/models/academy_session_model.dart';
import 'package:rafiq_academy/shared/domain/session_conflict_contract.dart';
import 'package:rafiq_academy/shared/domain/session_contract.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  group('WA-8 session contract / dual-read', () {
    test('C6 statuses are locked', () {
      expect(SessionContract.statuses, containsAll([
        'scheduled',
        'in_progress',
        'completed',
        'cancelled',
      ]));
      expect(SessionContract.isValidStatus('scheduled'), isTrue);
      expect(SessionContract.isValidStatus('live'), isFalse);
    });

    test('model round-trip preserves identity snapshot fields', () {
      final start = DateTime.utc(2026, 9, 13, 13, 0);
      final end = DateTime.utc(2026, 9, 13, 14, 0);
      final model = AcademySessionModel(
        id: 'sess_abc',
        halaqaId: 'h1',
        slotId: 'slot-1',
        date: '2026-09-13',
        startAt: start,
        endAt: end,
        status: SessionContract.statusScheduled,
        teacherId: 't1',
        supervisorId: 's1',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
        createdBy: 't1',
      );
      final map = model.toMap();
      final again = AcademySessionModel.fromMap('sess_abc', map);
      expect(again.halaqaId, 'h1');
      expect(again.slotId, 'slot-1');
      expect(again.date, '2026-09-13');
      expect(again.teacherId, 't1');
      expect(again.supervisorId, 's1');
      expect(again.status, SessionContract.statusScheduled);
      expect(again.createdBy, 't1');
    });

    test('legacy synthetic day ids still recognized for dual-read', () {
      final id = AttendancePolicy.sessionIdForDay(
        halaqaId: 'halaqaA',
        day: DateTime(2026, 9, 13),
      );
      expect(id, 'halaqaA_20260913');
      expect(AttendancePolicy.isLegacySyntheticSessionId(id), isTrue);
      expect(
        AttendancePolicy.isLegacySyntheticSessionId('sess_deadbeef'),
        isFalse,
      );
    });
  });

  group('WA-9 conflict contract', () {
    test('participant statuses match C7 filter', () {
      expect(
        SessionConflictContract.participatesInConflicts('scheduled'),
        isTrue,
      );
      expect(
        SessionConflictContract.participatesInConflicts('in_progress'),
        isTrue,
      );
      expect(
        SessionConflictContract.participatesInConflicts('cancelled'),
        isFalse,
      );
      expect(
        SessionConflictContract.participatesInConflicts('completed'),
        isFalse,
      );
    });
  });
}
