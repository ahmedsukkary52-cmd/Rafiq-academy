import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';

/// Counts Auth users eligible for an admin ops broadcast audience.
///
/// Lives in the data layer so presentation never talks to Firestore directly.
/// Pass the DI-resolved [FirebaseFirestore] (emulator-aware), never a hard-coded
/// `FirebaseFirestore.instance`, so local flavors hit the correct app.
Future<int> countBroadcastAudienceForRole({
  required FirebaseFirestore firestore,
  required String targetRole,
}) async {
  Query<Map<String, dynamic>> query = firestore.collection(
    FirestoreCollections.users,
  );
  if (targetRole != 'all') {
    query = query.where('role', isEqualTo: targetRole);
  }
  final snap = await query.count().get();
  return snap.count ?? 0;
}
