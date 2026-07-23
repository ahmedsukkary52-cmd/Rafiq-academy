import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../models/review_schedule_doc_model.dart';
import 'review_schedule_remote_datasource.dart';

@LazySingleton(as: ReviewScheduleRemoteDatasource)
class ReviewScheduleRemoteDatasourceImpl
    implements ReviewScheduleRemoteDatasource {
  final FirebaseFirestore firestore;

  ReviewScheduleRemoteDatasourceImpl(this.firestore);

  @override
  Future<List<ReviewScheduleDocModel>> getReviewsInRange({
    required String studentId,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.reviewSchedules)
          .where('studentId', isEqualTo: studentId)
          .where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive),
      )
          .where('date', isLessThan: Timestamp.fromDate(endExclusive))
          .orderBy('date')
          .get();

      return snapshot.docs
          .map(
            (doc) =>
            ReviewScheduleDocModel.fromMap(
              doc.id,
              doc.data(),
            ),
      )
          .toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
