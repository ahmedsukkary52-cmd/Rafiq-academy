import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exception.dart';
import '../../../shared/utils/firestore_in_query.dart';
import '../domain/entities/admin_payment_record.dart';
import '../domain/entities/financial_summary_entity.dart';

/// Admin read-only view over `payments` (external payments: parent proof →
/// supervisor review → verified record). Totals use server aggregates and
/// the list is keyset-paginated, so no read ever downloads the collection.
class AdminPaymentsLedger {
  AdminPaymentsLedger({required this.firestore});

  final FirebaseFirestore firestore;

  static const pageSize = 20;
  static const historyLimit = 20;

  CollectionReference<Map<String, dynamic>> get _payments =>
      firestore.collection(FirestoreCollections.payments);

  Future<FinancialSummaryEntity> summary() async {
    try {
      // A multi-field aggregate only covers documents having every field, so
      // the optional `amountPaidConfirmed` is summed in its own query.
      Query<Map<String, dynamic>> byStatus(String status) =>
          _payments.where('status', isEqualTo: status);
      Future<AggregateQuerySnapshot> invoices(String status) =>
          byStatus(status).aggregate(count(), sum('amount')).get();
      Future<AggregateQuerySnapshot> confirmed(String status) =>
          byStatus(status).aggregate(sum('amountPaidConfirmed')).get();
      final r = await Future.wait<AggregateQuerySnapshot>([
        invoices('paid'),
        invoices('due'),
        confirmed('due'),
        invoices('overdue'),
        confirmed('overdue'),
        _payments
            .where('reviewStatus', isEqualTo: 'pending_review')
            .count()
            .get(),
      ]);
      return summaryFromTotals(
        paid: StatusTotals.of(r[0]),
        due: StatusTotals.of(r[1], confirmed: r[2]),
        overdue: StatusTotals.of(r[3], confirmed: r[4]),
        awaitingReviewCount: r[5].count ?? 0,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<AdminPaymentPage> fetchPage({
    PaymentLedgerFilter filter = PaymentLedgerFilter.all,
    Object? cursor,
    int limit = pageSize,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _payments;
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
      q = q.orderBy('dueDate', descending: true).limit(limit);
      if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
      final snap = await q.get();
      final names = await _names(
        snap.docs.expand(
          (d) => [
            d.data()['studentId'] as String? ?? '',
            d.data()['parentId'] as String? ?? '',
          ],
        ),
      );
      return AdminPaymentPage(
        items: [
          for (final d in snap.docs) paymentRecordFromMap(d.id, d.data(), names),
        ],
        cursor: snap.docs.length < limit ? null : snap.docs.last,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Fresh record (including the reviewer's name) for the details view.
  Future<AdminPaymentRecord> record(String paymentId) async {
    try {
      final doc = await _payments.doc(paymentId).get();
      final data = doc.data();
      if (data == null) throw const ServerException('الدفعة غير موجودة');
      final names = await _names([
        data['studentId'] as String? ?? '',
        data['parentId'] as String? ?? '',
        data['reviewedBy'] as String? ?? '',
      ]);
      return paymentRecordFromMap(doc.id, data, names);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Review decisions recorded by `reviewPaymentProof` (Admin-only reads).
  Future<List<PaymentHistoryEntry>> history(String paymentId) async {
    try {
      final snap = await firestore
          .collection('auditLogs')
          .where('targetId', isEqualTo: paymentId)
          .limit(historyLimit)
          .get();
      final docs = snap.docs
          .where((d) => d.data()['targetType'] == 'payment')
          .toList();
      final names = await _names(
        docs.map((d) => d.data()['actorId'] as String? ?? ''),
      );
      final entries = [
        for (final d in docs) paymentHistoryFromMap(d.data(), names),
      ];
      entries.sort(
        (a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)),
      );
      return entries;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<Map<String, String>> _names(Iterable<String> ids) async {
    final out = <String, String>{};
    for (final chunk in FirestoreInQuery.chunkIds(ids)) {
      final snap = await firestore
          .collection(FirestoreCollections.users)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snap.docs) {
        final name = (d.data()['name'] as String? ?? '').trim();
        if (name.isNotEmpty) out[d.id] = name;
      }
    }
    return out;
  }
}

class StatusTotals {
  const StatusTotals({
    required this.count,
    required this.amount,
    required this.confirmed,
  });

  factory StatusTotals.of(
    AggregateQuerySnapshot invoices, {
    AggregateQuerySnapshot? confirmed,
  }) => StatusTotals(
    count: invoices.count ?? 0,
    amount: invoices.getSum('amount') ?? 0,
    confirmed: confirmed?.getSum('amountPaidConfirmed') ?? 0,
  );

  final int count;
  final double amount;
  final double confirmed;
}

/// Revenue = fully paid invoices + confirmed partials on unpaid ones;
/// outstanding = unpaid invoice amounts minus what was already confirmed.
FinancialSummaryEntity summaryFromTotals({
  required StatusTotals paid,
  required StatusTotals due,
  required StatusTotals overdue,
  required int awaitingReviewCount,
}) {
  double nonNegative(double v) => v < 0 ? 0 : v;
  return FinancialSummaryEntity(
    totalRevenue: paid.amount + due.confirmed + overdue.confirmed,
    totalPending: nonNegative(due.amount - due.confirmed),
    totalOverdue: nonNegative(overdue.amount - overdue.confirmed),
    paidCount: paid.count,
    dueCount: due.count,
    overdueCount: overdue.count,
    awaitingReviewCount: awaitingReviewCount,
  );
}

DateTime? _date(Object? raw) => raw is Timestamp
    ? raw.toDate()
    : raw is DateTime
    ? raw
    : null;

double? _num(Object? raw) => raw is num ? raw.toDouble() : null;

String? _text(Object? raw) {
  final s = raw is String ? raw.trim() : '';
  return s.isEmpty ? null : s;
}

AdminPaymentRecord paymentRecordFromMap(
  String id,
  Map<String, dynamic> data,
  Map<String, String> names,
) {
  final studentId = _text(data['studentId']) ?? '';
  final parentId = _text(data['parentId']) ?? '';
  final reviewer = _text(data['reviewedBy']);
  return AdminPaymentRecord(
    id: id,
    studentId: studentId,
    studentName: names[studentId] ?? 'طالب',
    parentId: parentId,
    parentName: names[parentId] ?? 'ولي أمر',
    amount: _num(data['amount']) ?? 0,
    status: _text(data['status']) ?? 'due',
    reviewStatus: _text(data['reviewStatus']),
    dueDate: _date(data['dueDate']),
    paidAt: _date(data['paidAt']),
    method: _text(data['method']),
    periodKey: _text(data['periodKey']),
    amountPaidConfirmed: _num(data['amountPaidConfirmed']),
    remainingAmount: _num(data['remainingAmount']),
    proofStoragePath: _text(data['proofStoragePath']),
    proofSubmittedAt: _date(data['proofSubmittedAt']),
    reviewedByName: reviewer == null ? null : (names[reviewer] ?? 'مشرف'),
    reviewedAt: _date(data['reviewedAt']),
    reviewNotes: _text(data['reviewNotes']),
  );
}

PaymentHistoryEntry paymentHistoryFromMap(
  Map<String, dynamic> data,
  Map<String, String> names,
) {
  final meta = data['metadata'] is Map
      ? Map<String, dynamic>.from(data['metadata'] as Map)
      : const <String, dynamic>{};
  final actor = _text(data['actorId']) ?? '';
  return PaymentHistoryEntry(
    at: _date(data['timestamp']),
    actorName: names[actor] ?? 'مشرف',
    decision: _text(meta['decision']) ?? '',
    newStatus: _text(meta['newStatus']) ?? '',
    receiptAmount: _num(meta['receiptAmount']),
    remainingAmount: _num(meta['remainingAmount']),
  );
}
