import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/admin_rewards_view.dart';

/// Thrown only for recoverable load failures (network / server).
/// Permission gaps and expected empty results are returned as `[]`.
class AdminRewardsHistoryLoadException implements Exception {
  final String message;
  const AdminRewardsHistoryLoadException(this.message);

  @override
  String toString() => message;
}

/// Most recent academy awards, newest first. Docs without a `date` field
/// (pre-dual-write teacher grants) are not part of this ordered query.
class AdminRewardsHistoryRepository {
  static const int pageSize = 30;

  final FirebaseFirestore _db;

  AdminRewardsHistoryRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  Future<List<AdminRewardHistoryEntry>> recent() async {
    try {
      final snap = await _db
          .collection('achievements')
          .orderBy('date', descending: true)
          .limit(pageSize)
          .get();
      return [
        for (final d in snap.docs)
          AdminRewardHistoryEntry.fromMap(
            d.id,
            d.data(),
            date: switch (d.data()['date']) {
              final Timestamp t => t.toDate(),
              _ => null,
            },
          ),
      ];
    } on FirebaseException catch (e) {
      // Soft-empty: no awards yet, missing index, or no read permission —
      // do not surface as a fake offline error.
      if (_isSoftEmptyCode(e.code)) return const [];
      if (_isNetworkCode(e.code)) {
        throw const AdminRewardsHistoryLoadException(
          'تعذر الاتصال. تحقق من الإنترنت ثم أعد المحاولة',
        );
      }
      throw const AdminRewardsHistoryLoadException('تعذر تحميل سجل الجوائز');
    }
  }

  static bool _isSoftEmptyCode(String code) =>
      code == 'permission-denied' ||
      code == 'not-found' ||
      code == 'failed-precondition';

  static bool _isNetworkCode(String code) =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'network-request-failed';
}
