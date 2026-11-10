import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exception.dart';
import '../domain/complaint.dart';

/// Complaints data access. Writes go only through the callables; reads are
/// cursor-paginated (`createdAt desc`) and scoped by the rules to the Admin
/// or the complainant.
class ComplaintsRepository {
  ComplaintsRepository({required this.firestore, required this.functions});

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  static const pageSize = 20;

  CollectionReference<Map<String, dynamic>> get _complaints =>
      firestore.collection(FirestoreCollections.complaints);

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await functions.httpsCallable(name).call(payload);
      final data = result.data;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<String> submit({
    required String subject,
    required String message,
    String? studentId,
    String? halaqaId,
  }) async {
    final data = await _call('submitComplaint', {
      'subject': subject.trim(),
      'message': message.trim(),
      if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
      if (halaqaId != null && halaqaId.isNotEmpty) 'halaqaId': halaqaId,
    });
    return data['complaintId'] as String? ?? '';
  }

  /// Admin: reply and/or [status]. Complainant: reply only.
  Future<ComplaintStatus> respond({
    required String complaintId,
    String? message,
    ComplaintStatus? status,
  }) async {
    final data = await _call('respondToComplaint', {
      'complaintId': complaintId,
      if (message != null && message.trim().isNotEmpty)
        'message': message.trim(),
      if (status != null) 'status': status.wire,
    });
    return ComplaintStatus.fromWire(data['status']);
  }

  /// [senderId] scopes to the complainant's own threads; [status] filters
  /// the Admin queue. Both use composite indexes with `createdAt desc`.
  Future<ComplaintPage> fetchPage({
    String? senderId,
    ComplaintStatus? status,
    Object? cursor,
    int limit = pageSize,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _complaints;
      if (senderId != null) q = q.where('senderId', isEqualTo: senderId);
      if (status != null) q = q.where('status', isEqualTo: status.wire);
      q = q.orderBy('createdAt', descending: true).limit(limit);
      if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
      final snap = await q.get();
      return ComplaintPage(
        items: snap.docs.map(complaintFromMap).toList(),
        cursor: snap.docs.length < limit ? null : snap.docs.last,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Stream<Complaint?> watchComplaint(String id) => _complaints
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? complaintFromMap(d) : null);

  Stream<List<ComplaintHistoryEntry>> watchHistory(String id) => _complaints
      .doc(id)
      .collection('history')
      .orderBy('createdAt')
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(historyFromMap).toList());

  /// Children (parent) or halaqat (teacher / supervisor) the complaint may
  /// reference. Bounded by the caller's own relationships.
  Future<List<ComplaintContextOption>> contextOptions({
    required String uid,
    required String role,
  }) async {
    try {
      if (role == 'parent') {
        final profile = await firestore
            .collection(FirestoreCollections.parentProfiles)
            .doc(uid)
            .get();
        final ids = (profile.data()?['childrenIds'] as List? ?? const [])
            .whereType<String>()
            .take(20)
            .toList();
        final users = await Future.wait(
          ids.map(
            (id) =>
                firestore.collection(FirestoreCollections.users).doc(id).get(),
          ),
        );
        return [
          for (final u in users)
            ComplaintContextOption.student(
              u.id,
              (u.data()?['name'] as String?)?.trim().isNotEmpty == true
                  ? (u.data()!['name'] as String).trim()
                  : 'طالب',
            ),
        ];
      }
      final field = switch (role) {
        'teacher' => 'teacherId',
        'supervisor' => 'supervisorId',
        _ => null,
      };
      if (field == null) return const [];
      final snap = await firestore
          .collection(FirestoreCollections.halaqat)
          .where(field, isEqualTo: uid)
          .limit(50)
          .get();
      return [
        for (final d in snap.docs)
          ComplaintContextOption.halaqa(
            d.id,
            (d.data()['name'] as String?)?.trim() ?? 'حلقة',
          ),
      ];
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}

DateTime? _date(Object? raw) => raw is Timestamp ? raw.toDate() : null;

String _text(Object? raw) => raw is String ? raw.trim() : '';

Complaint complaintFromMap(DocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data() ?? const <String, dynamic>{};
  final legacy = _text(d['response']);
  return Complaint(
    id: doc.id,
    senderId: _text(d['senderId']),
    senderRole: _text(d['senderRole']),
    senderName: _text(d['senderName']),
    subject: _text(d['subject']),
    message: _text(d['message']),
    status: ComplaintStatus.fromWire(d['status']),
    createdAt: _date(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: _date(d['updatedAt']),
    studentId: _text(d['studentId']).isEmpty ? null : _text(d['studentId']),
    studentName: _text(d['studentName']),
    halaqaId: _text(d['halaqaId']).isEmpty ? null : _text(d['halaqaId']),
    halaqaName: _text(d['halaqaName']),
    historyCount: (d['historyCount'] as num?)?.toInt() ?? 0,
    legacyResponse: legacy.isEmpty ? null : legacy,
  );
}

ComplaintHistoryEntry historyFromMap(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final d = doc.data() ?? const <String, dynamic>{};
  return ComplaintHistoryEntry(
    id: doc.id,
    authorId: _text(d['authorId']),
    authorRole: _text(d['authorRole']),
    authorName: _text(d['authorName']),
    message: _text(d['message']),
    statusFrom: ComplaintStatus.fromWire(d['statusFrom']),
    statusTo: ComplaintStatus.fromWire(d['statusTo']),
    createdAt: _date(d['createdAt']),
  );
}
