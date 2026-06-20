import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../models/parent_model.dart';

@LazySingleton(as: ParentRemoteDatasource)
class ParentRemoteDatasourceImpl implements ParentRemoteDatasource {
  final FirebaseFirestore firestore;

  const ParentRemoteDatasourceImpl({required this.firestore});

  @override
  Future<List<String>> getChildrenIds(String parentId) async {
    try {
      final doc = await firestore
          .collection(FirestoreCollections.parentProfiles)
          .doc(parentId)
          .get();

      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['childrenIds'] ?? []);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<WeeklyReportModel> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  }) async {
    try {
      final weekEnd = weekStart.add(const Duration(days: 7));

      final attendanceSnap = await firestore
          .collection(FirestoreCollections.attendanceRecords)
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('date', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      final recitationSnap = await firestore
          .collection(FirestoreCollections.recitationRecords)
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('date', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      final userDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(studentId)
          .get();

      final studentName =
          (userDoc.data() as Map<String, dynamic>?)?['name'] ?? '';

      final attended = attendanceSnap.docs
          .where((d) => (d.data())['status'] == 'present')
          .length;

      final lastNote = recitationSnap.docs.isNotEmpty
          ? (recitationSnap.docs.last.data())['notes'] as String? ?? ''
          : '';

      return WeeklyReportModel.fromMap(
        studentId: studentId,
        studentName: studentName,
        weekStart: weekStart,
        data: {
          'totalVersesMemorized': recitationSnap.docs.length,
          'attendedSessions': attended,
          'totalSessions': attendanceSnap.docs.length,
          'teacherNotes': lastNote,
        },
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<PaymentModel>> getPayments(String parentId) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.payments)
          .where('parentId', isEqualTo: parentId)
          .orderBy('dueDate', descending: true)
          .get();

      return snapshot.docs.map(PaymentModel.fromFirestore).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> submitAbsenceRequest(AbsenceRequestModel request) async {
    try {
      await firestore
          .collection(FirestoreCollections.absenceRequests)
          .add(request.toFirestore());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
