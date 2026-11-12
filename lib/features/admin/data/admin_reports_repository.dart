import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exception.dart';
import '../../../shared/utils/firestore_in_query.dart';
import '../domain/admin_reports.dart';
import '../domain/entities/admin_payment_record.dart';
import 'admin_payments_ledger.dart' show paymentRecordFromMap;

typedef Capped<T> = ({List<T> items, bool truncated});

/// Date-ranged reads for the Admin reports: one bounded query per report
/// (existing indexes), names resolved in batches of 30, never per row.
class AdminReportsRepository {
  AdminReportsRepository({required this.firestore});

  final FirebaseFirestore firestore;

  static const attendanceCap = 5000;
  static const sessionsCap = 5000;
  static const paymentsCap = 2000;

  Future<Capped<AttendanceRow>> attendance(
    ReportRange range, {
    String? halaqaId,
  }) => _guard(() async {
    Query<Map<String, dynamic>> q = firestore.collection('attendanceRecords');
    if (halaqaId != null) q = q.where('halaqaId', isEqualTo: halaqaId);
    final snap = await q
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.from))
        .where('date', isLessThan: Timestamp.fromDate(range.endExclusive))
        .orderBy('date')
        .limit(attendanceCap)
        .get();
    return (
      items: [
        for (final d in snap.docs)
          if (d.data()['date'] is Timestamp)
            AttendanceRow(
              studentId: '${d.data()['studentId'] ?? ''}',
              halaqaId: '${d.data()['halaqaId'] ?? ''}',
              status: '${d.data()['status'] ?? ''}',
              date: (d.data()['date'] as Timestamp).toDate(),
            ),
      ],
      truncated: snap.docs.length >= attendanceCap,
    );
  });

  Future<Capped<SessionRow>> sessions(ReportRange range) => _guard(() async {
    final snap = await firestore
        .collection('sessions')
        .where('date', isGreaterThanOrEqualTo: range.fromKey)
        .where('date', isLessThanOrEqualTo: range.toKey)
        .orderBy('date')
        .limit(sessionsCap)
        .get();
    return (
      items: [
        for (final d in snap.docs)
          SessionRow(
            teacherId: '${d.data()['teacherId'] ?? ''}',
            status: '${d.data()['status'] ?? ''}',
            date: '${d.data()['date'] ?? ''}',
          ),
      ],
      truncated: snap.docs.length >= sessionsCap,
    );
  });

  Future<Capped<AdminPaymentRecord>> payments(
    ReportRange range, {
    PaymentLedgerFilter filter = PaymentLedgerFilter.all,
  }) => _guard(() async {
    Query<Map<String, dynamic>> q = firestore.collection(
      FirestoreCollections.payments,
    );
    q = switch (filter) {
      PaymentLedgerFilter.all => q,
      PaymentLedgerFilter.awaitingReview => q.where(
        'reviewStatus',
        isEqualTo: 'pending_review',
      ),
      PaymentLedgerFilter.due => q.where('status', isEqualTo: 'due'),
      PaymentLedgerFilter.overdue => q.where('status', isEqualTo: 'overdue'),
      PaymentLedgerFilter.paid => q.where('status', isEqualTo: 'paid'),
    };
    final snap = await q
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(range.from))
        .where('dueDate', isLessThan: Timestamp.fromDate(range.endExclusive))
        .orderBy('dueDate', descending: true)
        .limit(paymentsCap)
        .get();
    final names = await _names(
      snap.docs.expand(
        (d) => ['${d.data()['studentId'] ?? ''}', '${d.data()['parentId'] ?? ''}'],
      ),
    );
    return (
      items: [
        for (final d in snap.docs) paymentRecordFromMap(d.id, d.data(), names),
      ],
      truncated: snap.docs.length >= paymentsCap,
    );
  });

  Future<Map<String, String>> _names(Iterable<String> ids) async {
    final out = <String, String>{};
    for (final chunk in FirestoreInQuery.chunkIds(ids)) {
      final snap = await firestore
          .collection(FirestoreCollections.users)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snap.docs) {
        final name = '${d.data()['name'] ?? ''}'.trim();
        if (name.isNotEmpty) out[d.id] = name;
      }
    }
    return out;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseException catch (e) {
      throw ServerException(
        e.code == 'permission-denied'
            ? 'لا تملك صلاحية قراءة بيانات التقرير'
            : e.code == 'failed-precondition'
            ? 'التقرير يحتاج فهرساً غير منشور بعد في قاعدة البيانات'
            : 'تعذر تحميل بيانات التقرير. تحقق من الاتصال.',
      );
    } catch (_) {
      throw const ServerException('تعذر تحميل بيانات التقرير. تحقق من الاتصال.');
    }
  }
}
