import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/student/data/models/assignment_model.dart';

/// Shared homework-field seed for legacy `assignments` docs (H2 / A-H12).
///
/// Write path ([TeacherRemoteDatasourceImpl.sendAssignment]) already seeds
/// via [AssignmentModel.defaultHomeworkFields]. This helper is the single
/// read-side repair for older docs missing `tasks`.
class AssignmentHomeworkFieldsEnsure {
  const AssignmentHomeworkFieldsEnsure._();

  /// Returns `true` when a merge-write was performed.
  static Future<bool> ensureOnDocument(DocumentSnapshot doc) async {
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) return false;
    final tasks = raw['tasks'];
    if (tasks is List && tasks.isNotEmpty) return false;

    final seed = AssignmentModel.defaultHomeworkFields(
      newMemorizationRange: raw['newMemorizationRange'] as String? ?? '',
      reviewRange: raw['reviewRange'] as String? ?? '',
    );
    await doc.reference.set(seed, SetOptions(merge: true));
    return true;
  }
}
