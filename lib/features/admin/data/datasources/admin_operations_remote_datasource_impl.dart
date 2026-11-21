import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../core/firebase/callable_invoke.dart';
import '../../../../shared/data/payment_review_callable.dart';
import '../../../../shared/domain/payment_review_amounts.dart';
import '../../../../shared/domain/parent_payment_proof.dart';
import '../../../../shared/data/models/halaqa_model.dart';
import '../../../../shared/domain/halaqa_entity.dart';
import '../../../../shared/utils/firestore_in_query.dart';
import '../../domain/entities/admin_operations_entities.dart';
import 'admin_operations_remote_datasource.dart';

@LazySingleton(as: AdminOperationsRemoteDatasource)
class AdminOperationsRemoteDatasourceImpl
    implements AdminOperationsRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const AdminOperationsRemoteDatasourceImpl({
    required this.firestore,
    required this.functions,
  });

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) =>
      invokeCallable(functions, name, payload);

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AdminDirectoryUser>> listUsersByRole(String role) {
    return _guard(() async {
      final snap = await firestore
          .collection(FirestoreCollections.users)
          .where('role', isEqualTo: role)
          .get();
      final users = snap.docs.map((doc) {
        final d = doc.data();
        return AdminDirectoryUser(
          uid: doc.id,
          name: (d['name'] as String?)?.trim() ?? '',
          role: (d['role'] as String?) ?? role,
          isActive: d['isActive'] != false,
        );
      }).toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
      return users;
    });
  }

  @override
  Future<List<HalaqaEntity>> listHalaqat() {
    return _guard(() async {
      final snap = await firestore
          .collection(FirestoreCollections.halaqat)
          .get();
      final halaqat = snap.docs.map(HalaqaModel.fromFirestore).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return halaqat;
    });
  }

  @override
  Future<List<String>> getParentChildrenIds(String parentId) {
    return _guard(() async {
      final doc = await firestore
          .collection(FirestoreCollections.parentProfiles)
          .doc(parentId.trim())
          .get();
      final raw = doc.data()?['childrenIds'];
      return raw is List ? raw.whereType<String>().toList() : const [];
    });
  }

  @override
  Future<ParentLinkResult> linkParentChild({
    required String parentId,
    required String studentId,
    required ParentLinkOperation operation,
  }) async {
    final data = await _call('adminLinkParentChild', {
      'parentId': parentId,
      'studentId': studentId,
      'operation': operation.wire,
    });
    final ids = data['childrenIds'];
    return ParentLinkResult(
      childrenIds: ids is List ? ids.whereType<String>().toList() : const [],
      changed: data['changed'] == true,
    );
  }

  @override
  Future<String> createHalaqa({
    required String name,
    required String teacherId,
    String? supervisorId,
    String? meetingLink,
    required List<HalaqaSlotInput> schedule,
    required String requestId,
  }) async {
    final data = await _call('adminCreateHalaqa', {
      'name': name,
      'teacherId': teacherId,
      if (supervisorId != null && supervisorId.isNotEmpty)
        'supervisorId': supervisorId,
      if (meetingLink != null && meetingLink.isNotEmpty)
        'meetingLink': meetingLink,
      'schedule': schedule.map((s) => s.toMap()).toList(),
      'requestId': requestId,
    });
    final id = data['halaqaId'];
    if (id is String && id.isNotEmpty) return id;
    throw const ServerException('تعذر إنشاء الحلقة: رد غير متوقع');
  }

  @override
  Future<String> addHalaqaSlot({
    required String halaqaId,
    required HalaqaSlotInput slot,
  }) async {
    final data = await _call('adminAddHalaqaSlot', {
      'halaqaId': halaqaId,
      'slot': slot.toMap(),
    });
    final id = data['slotId'];
    if (id is String && id.isNotEmpty) return id;
    throw const ServerException('تعذر إضافة الموعد: رد غير متوقع');
  }

  @override
  Future<MeetingLinkChange> setHalaqaMeetingLink({
    required String halaqaId,
    String? meetingLink,
    bool clear = false,
  }) async {
    final data = await _call('setHalaqaMeetingLink', {
      'halaqaId': halaqaId,
      if (clear) 'clear': true else 'meetingLink': meetingLink ?? '',
    });
    return meetingLinkChangeFromWire(data['operation']);
  }

  @override
  Future<void> transferStudent({
    required String studentId,
    required String fromHalaqaId,
    required String toHalaqaId,
  }) async {
    await _call('adminTransferStudent', {
      'studentId': studentId,
      'fromHalaqaId': fromHalaqaId,
      'toHalaqaId': toHalaqaId,
    });
  }

  Query<Map<String, dynamic>> get _pending => firestore
      .collection(FirestoreCollections.payments)
      .where(
        ParentPaymentProofContract.reviewStatusField,
        isEqualTo: ParentPaymentProofContract.pendingReview,
      );

  @override
  Future<List<PaymentReviewItem>> listPendingPaymentProofs({
    required String reviewerUid,
    required bool isAdmin,
  }) {
    return _guard(() async {
      final items = <PaymentReviewItem>[];
      if (isAdmin) {
        final snap = await _pending.get();
        items.addAll(
          snap.docs.map((d) => paymentReviewItemFromMap(d.id, d.data())),
        );
      } else {
        // Supervisor: rules allow per-student queries for students whose
        // primary Halaqa they supervise (isSupervisorOfStudent).
        final halaqat = await firestore
            .collection(FirestoreCollections.halaqat)
            .where('supervisorId', isEqualTo: reviewerUid)
            .get();
        final studentIds = FirestoreInQuery.normalizeIds([
          for (final h in halaqat.docs)
            ...((h.data()['studentIds'] as List?)?.whereType<String>() ??
                const <String>[]),
        ]);
        // Parallelize per-student pending queries (bounded concurrency via
        // whereIn-sized chunks) — avoids serial N+1 latency.
        const parallel = 8;
        for (var i = 0; i < studentIds.length; i += parallel) {
          final slice = studentIds.sublist(
            i,
            i + parallel > studentIds.length
                ? studentIds.length
                : i + parallel,
          );
          final pages = await Future.wait(
            slice.map((studentId) async {
              try {
                final snap = await _pending
                    .where('studentId', isEqualTo: studentId)
                    .get();
                return snap.docs
                    .map((d) => paymentReviewItemFromMap(d.id, d.data()))
                    .toList();
              } on FirebaseException catch (e) {
                // Student's primary Halaqa is supervised by someone else.
                if (e.code == 'permission-denied') {
                  return const <PaymentReviewItem>[];
                }
                rethrow;
              }
            }),
          );
          for (final page in pages) {
            items.addAll(page);
          }
        }
      }
      final names = await _studentNames(
        items.map((item) => item.studentId),
      );
      final named = [
        for (final item in items)
          item.withStudentName(names[item.studentId] ?? ''),
      ];
      named.sort((a, b) {
        final ta = a.proofSubmittedAt ?? DateTime(2000);
        final tb = b.proofSubmittedAt ?? DateTime(2000);
        return ta.compareTo(tb);
      });
      return named;
    });
  }

  /// Batch `users` name reads via `whereIn` chunks (no per-student get).
  Future<Map<String, String>> _studentNames(Iterable<String> ids) async {
    final out = <String, String>{};
    for (final chunk in FirestoreInQuery.chunkIds(ids)) {
      final snap = await firestore
          .collection(FirestoreCollections.users)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snap.docs) {
        out[d.id] = (d.data()['name'] as String?)?.trim() ?? '';
      }
    }
    return out;
  }

  @override
  Future<PaymentReviewResult> reviewPaymentProof({
    required PaymentReviewCommand command,
    required String requestId,
  }) async {
    final data = await _call(
      'reviewPaymentProof',
      reviewPaymentProofPayload(command, requestId: requestId),
    );
    return reviewPaymentProofResult(data, command);
  }
}
