import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../models/progress_report_source_model.dart';
import 'progress_report_remote_datasource.dart';

@LazySingleton(as: ProgressReportRemoteDatasource)
class ProgressReportRemoteDatasourceImpl
    implements ProgressReportRemoteDatasource {
  final FirebaseFirestore firestore;

  ProgressReportRemoteDatasourceImpl(this.firestore);

  @override
  Future<ProgressReportSourceModel> getReportSource({
    required String studentId,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    try {
      final attendanceSnap = await firestore
          .collection(FirestoreCollections.attendanceRecords)
          .where('studentId', isEqualTo: studentId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive),
          )
          .where('date', isLessThan: Timestamp.fromDate(endExclusive))
          .get();

      final recitationSnap = await firestore
          .collection(FirestoreCollections.recitationRecords)
          .where('studentId', isEqualTo: studentId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive),
          )
          .where('date', isLessThan: Timestamp.fromDate(endExclusive))
          .get();

      return ProgressReportSourceModel(
        studentId: studentId,
        rangeStart: startInclusive,
        rangeEnd: endExclusive,
        attendance: attendanceSnap.docs.map(_attendanceFromDoc).toList(),
        recitations: recitationSnap.docs.map(_recitationFromDoc).toList(),
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  ProgressAttendanceDocModel _attendanceFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawDate = data['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : (rawDate as DateTime? ?? DateTime.now());
    return ProgressAttendanceDocModel(
      id: doc.id,
      halaqaId: (data['halaqaId'] as String?)?.trim() ?? '',
      date: date,
      status: (data['status'] as String?)?.trim() ?? '',
    );
  }

  ProgressRecitationDocModel _recitationFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawDate = data['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : (rawDate as DateTime? ?? DateTime.now());
    return ProgressRecitationDocModel(
      id: doc.id,
      date: date,
      notes: data['notes'] as String?,
      reviewStatus: (data['reviewStatus'] as String?) ?? 'reviewed',
    );
  }
}
