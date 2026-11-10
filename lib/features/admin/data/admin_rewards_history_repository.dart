import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/admin_rewards_view.dart';

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
    } on FirebaseException {
      throw 'تعذر تحميل سجل الجوائز';
    }
  }
}
