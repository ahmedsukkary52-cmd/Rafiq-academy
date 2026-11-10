import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exception.dart';

/// Server lifecycle of a teacher/supervisor account (`users.staffStatus`).
enum StaffStatus {
  active('active', 'نشط'),
  deactivated('deactivated', 'معطّل'),
  archived('archived', 'مؤرشف'),
  deleted('deleted', 'محذوف');

  const StaffStatus(this.wire, this.label);
  final String wire;
  final String label;

  /// Missing `staffStatus` derives from `isActive`, like the server.
  static StaffStatus fromUser(Map<String, dynamic> data) {
    final raw = data['staffStatus'];
    for (final s in values) {
      if (s.wire == raw) return s;
    }
    return data['isActive'] == false ? deactivated : active;
  }
}

enum StaffAction {
  deactivate('deactivate'),
  reactivate('reactivate'),
  archive('archive'),
  delete('delete');

  const StaffAction(this.wire);
  final String wire;

  static List<StaffAction> availableFor(StaffStatus status) => switch (status) {
    StaffStatus.active => const [deactivate],
    StaffStatus.deactivated => const [reactivate, archive],
    StaffStatus.archived => const [reactivate, delete],
    StaffStatus.deleted => const [],
  };
}

class StaffMember {
  final String uid;
  final String name;
  final String role;
  final StaffStatus status;
  final String? profileImageUrl;

  const StaffMember({
    required this.uid,
    required this.name,
    required this.role,
    required this.status,
    this.profileImageUrl,
  });
}

class StaffHalaqa {
  final String id;
  final String name;

  const StaffHalaqa({required this.id, required this.name});
}

/// Admin staff lifecycle. All state changes go through callables
/// (`adminSetStaffStatus`, `adminReassignHalaqaStaff`); rules forbid the
/// client from writing staff status directly.
class StaffLifecycleRepository {
  StaffLifecycleRepository({required this.firestore, required this.functions});

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  static const maxStaffListed = 300;

  String _field(String role) =>
      role == AppRoles.teacher ? 'teacherId' : 'supervisorId';

  /// Every non-deleted member of [role], active first then by name.
  Future<List<StaffMember>> listStaff(String role) async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.users)
          .where('role', isEqualTo: role)
          .limit(maxStaffListed)
          .get();
      final list = snap.docs
          .map((d) {
            final data = d.data();
            return StaffMember(
              uid: d.id,
              name: (data['name'] as String? ?? '').trim(),
              role: role,
              status: StaffStatus.fromUser(data),
              profileImageUrl: data['profileImageUrl'] as String?,
            );
          })
          .where((m) => m.status != StaffStatus.deleted)
          .toList();
      list.sort((a, b) {
        final byStatus = a.status.index.compareTo(b.status.index);
        return byStatus != 0 ? byStatus : a.name.compareTo(b.name);
      });
      return list;
    } catch (e) {
      throw const ServerException('تعذر تحميل قائمة الطاقم');
    }
  }

  /// Open halaqat that still point at [uid] in [role].
  Future<List<StaffHalaqa>> assignedHalaqat(String uid, String role) async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.halaqat)
          .where(_field(role), isEqualTo: uid)
          .get();
      return snap.docs
          .where((d) {
            final status = d.data()['status'];
            return status != 'archived' && status != 'closed';
          })
          .map(
            (d) => StaffHalaqa(
              id: d.id,
              name: (d.data()['name'] as String? ?? '').trim(),
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      throw const ServerException('تعذر تحميل حلقات الحساب');
    }
  }

  /// Active members of [role] who can take over, excluding [excludeUid].
  Future<List<StaffMember>> replacements(
    String role, {
    required String excludeUid,
  }) async {
    final all = await listStaff(role);
    return all
        .where((m) => m.status == StaffStatus.active && m.uid != excludeUid)
        .toList();
  }

  Future<void> reassign({
    required String halaqaId,
    required String role,
    required String newStaffId,
  }) => _call('adminReassignHalaqaStaff', {
    'halaqaId': halaqaId,
    'role': role,
    'newStaffId': newStaffId,
  });

  Future<void> setStatus({required String uid, required StaffAction action}) =>
      _call('adminSetStaffStatus', {'uid': uid, 'action': action.wire});

  Future<void> _call(String name, Map<String, dynamic> payload) async {
    try {
      await functions.httpsCallable(name).call<dynamic>(payload);
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim() ?? '';
      throw ServerException(
        message.isNotEmpty && !message.contains(RegExp('[A-Za-z]{6,}'))
            ? message
            : 'تعذر إتمام العملية، حاول مرة أخرى',
      );
    } catch (_) {
      throw const ServerException('تعذر إتمام العملية، حاول مرة أخرى');
    }
  }
}
