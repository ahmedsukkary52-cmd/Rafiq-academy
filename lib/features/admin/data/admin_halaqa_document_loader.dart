import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/data/models/halaqa_model.dart';

/// Loads a single halaqa document for admin directory details.
///
/// Presentation must inject the DI [FirebaseFirestore] so emulator/local
/// flavors do not hit the wrong Firebase app via `FirebaseFirestore.instance`.
Future<HalaqaModel> loadAdminHalaqaDocument({
  required FirebaseFirestore firestore,
  required String halaqaId,
}) async {
  final DocumentSnapshot doc;
  try {
    doc = await firestore
        .collection(FirestoreCollections.halaqat)
        .doc(halaqaId)
        .get();
  } on FirebaseException {
    throw 'تعذر تحميل بيانات الحلقة';
  }
  if (!doc.exists) throw 'الحلقة غير موجودة';
  return HalaqaModel.fromFirestore(doc);
}
