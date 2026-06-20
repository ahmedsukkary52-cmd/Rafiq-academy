import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/supervisor/data/data_sources/supervisor_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../student/data/models/halaqa_model.dart';
import '../../domain/entities/achievement_issue_entity.dart';
import '../../domain/entities/supervisor_report_entity.dart';

@LazySingleton(as: SupervisorRemoteDatasource)
class SupervisorRemoteDatasourceImpl implements SupervisorRemoteDatasource {
  final FirebaseFirestore firestore;

  const SupervisorRemoteDatasourceImpl({required this.firestore});

  @override
  Future<List<HalaqaModel>> getSupervisedHalaqat(String supervisorId) async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.halaqat)
          .where('supervisorId', isEqualTo: supervisorId)
          .get();
      return snap.docs.map(HalaqaModel.fromFirestore).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> issueAchievement(AchievementIssueEntity data) async {
    try {
      await firestore.collection(FirestoreCollections.achievements).add({
        'studentId': data.studentId,
        'type': data.type,
        'title': data.title,
        'issuedBy': data.issuedBy,
        'date': Timestamp.now(),
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> submitReport(SupervisorReportEntity report) async {
    try {
      await firestore.collection(FirestoreCollections.supervisorReports).add({
        'supervisorId': report.supervisorId,
        if (report.halaqaId != null) 'halaqaId': report.halaqaId,
        if (report.teacherId != null) 'teacherId': report.teacherId,
        'type': report.type,
        'content': report.content,
        'date': Timestamp.fromDate(report.date),
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> registerNewStudent({
    required String halaqaId,
    required String studentId,
  }) async {
    try {
      await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .update({
            'studentIds': FieldValue.arrayUnion([studentId]),
          });

      await firestore
          .collection(FirestoreCollections.studentProfiles)
          .doc(studentId)
          .update({'halaqaId': halaqaId});
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
