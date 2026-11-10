import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/domain/assignment_policy.dart';
import '../../../../shared/data/models/assignment_model.dart';
import '../../../../shared/domain/assignment_entity.dart';

abstract class HalaqaPlanRemoteDatasource {
  Future<List<AssignmentEntity>> getLessonAssignments(String studentId);
}

@LazySingleton(as: HalaqaPlanRemoteDatasource)
class HalaqaPlanRemoteDatasourceImpl implements HalaqaPlanRemoteDatasource {
  final FirebaseFirestore firestore;

  /// History window; same (studentId, dueDate desc) index as the homework feed.
  static const int historyLimit = 100;

  HalaqaPlanRemoteDatasourceImpl(this.firestore);

  @override
  Future<List<AssignmentEntity>> getLessonAssignments(String studentId) async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.assignments)
          .where(AssignmentPolicy.studentIdField, isEqualTo: studentId)
          .orderBy(AssignmentPolicy.dueDateField, descending: true)
          .limit(historyLimit)
          .get();
      return [
        for (final doc in snap.docs)
          if (AssignmentPolicy.isLessonHomeworkData(doc.data()))
            AssignmentModel.fromFirestore(doc),
      ];
    } on FirebaseException catch (e) {
      throw ServerException(
        e.code == 'permission-denied'
            ? 'لا تملك صلاحية عرض خطة الحلقة'
            : 'تعذر تحميل خطة الحلقة',
      );
    }
  }
}
