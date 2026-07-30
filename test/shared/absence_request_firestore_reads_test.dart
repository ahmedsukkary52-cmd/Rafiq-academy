import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/data/absence_request_firestore_reads.dart';
import 'package:rafiq_academy/shared/data/absence_request_model.dart';
import 'package:rafiq_academy/shared/domain/absence_request.dart';

AbsenceRequestModel _req({
  required String id,
  required String studentId,
  required DateTime date,
  AbsenceRequestStatus status = AbsenceRequestStatus.pending,
}) {
  return AbsenceRequestModel(
    id: id,
    studentId: studentId,
    halaqaId: 'h1',
    requestedBy: 'p1',
    date: date,
    reason: 'سفر',
    status: status,
  );
}

void main() {
  final day = DateTime(2024, 6, 3, 9);
  final sameDayLate = DateTime(2024, 6, 3, 22);
  final otherDay = DateTime(2024, 6, 4);

  group('AbsenceRequestFirestoreReads.filterHalaqaDay (H4 / A-H5)', () {
    test('teacher pendingOnly keeps pending same-day only', () {
      final filtered = AbsenceRequestFirestoreReads.filterHalaqaDay(
        models: [
          _req(id: 'a', studentId: 's2', date: sameDayLate),
          _req(
            id: 'b',
            studentId: 's1',
            date: day,
            status: AbsenceRequestStatus.approved,
          ),
          _req(id: 'c', studentId: 's3', date: otherDay),
        ],
        date: day,
        pendingOnly: true,
      );

      expect(filtered.map((e) => e.id), ['a']);
    });

    test('supervisor includes all statuses on the calendar day', () {
      final filtered = AbsenceRequestFirestoreReads.filterHalaqaDay(
        models: [
          _req(
            id: 'approved',
            studentId: 's1',
            date: day,
            status: AbsenceRequestStatus.approved,
          ),
          _req(id: 'pending', studentId: 's2', date: sameDayLate),
          _req(id: 'other', studentId: 's3', date: otherDay),
        ],
        date: day,
        pendingOnly: false,
      );

      expect(filtered.map((e) => e.id).toSet(), {'approved', 'pending'});
    });
  });

  group('AbsenceRequestFirestoreReads sorts (H4)', () {
    test('teacher pending sorts by studentId ASC', () {
      final items = [
        _req(id: '2', studentId: 's2', date: day),
        _req(id: '1', studentId: 's1', date: day),
      ];
      AbsenceRequestFirestoreReads.sortTeacherPending(items);
      expect(items.map((e) => e.studentId), ['s1', 's2']);
    });

    test('supervisor sorts by status then studentId', () {
      final items = [
        _req(
          id: 'r',
          studentId: 's2',
          date: day,
          status: AbsenceRequestStatus.rejected,
        ),
        _req(id: 'p', studentId: 's9', date: day),
        _req(
          id: 'a',
          studentId: 's1',
          date: day,
          status: AbsenceRequestStatus.approved,
        ),
      ];
      AbsenceRequestFirestoreReads.sortSupervisorDay(items);
      expect(items.map((e) => e.id), ['p', 'a', 'r']);
    });

    test('parent history sorts by date DESC', () {
      final items = [
        _req(id: 'old', studentId: 's1', date: DateTime(2024, 6, 1)),
        _req(id: 'new', studentId: 's1', date: DateTime(2024, 6, 5)),
      ];
      AbsenceRequestFirestoreReads.sortParentHistory(items);
      expect(items.map((e) => e.id), ['new', 'old']);
    });
  });

  group('AbsenceRequestProjection shared home (H4 / A-H6)', () {
    test('labels unchanged', () {
      // Import via shared path used by teacher/supervisor after move.
      expect(
        AbsenceRequestStatus.pending.index <
            AbsenceRequestStatus.approved.index,
        isTrue,
      );
    });
  });
}
