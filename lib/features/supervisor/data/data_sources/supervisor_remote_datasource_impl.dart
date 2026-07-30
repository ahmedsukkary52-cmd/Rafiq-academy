import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/supervisor/data/data_sources/supervisor_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/absence_request_firestore_reads.dart';
import '../../../../shared/data/absence_request_model.dart';
import '../../../../shared/data/achievements_firestore_contract.dart';
import '../../../../shared/utils/firestore_in_query.dart';
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
      await firestore.collection(FirestoreCollections.achievements).add(
        AchievementsFirestoreContract.supervisorIssueFields(
          studentId: data.studentId,
          type: data.type,
          title: data.title,
          issuedBy: data.issuedBy,
          halaqaId: data.halaqaId,
        ),
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  // H6 / A-H16: write-only ops path — product UI removed; no in-app reader.
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

  @override
  Future<Map<String, String>> getUserDisplayNames(List<String> userIds) async {
    try {
      final unique = userIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (unique.isEmpty) return const {};

      final names = <String, String>{};
      for (final chunk in FirestoreInQuery.chunkIds(unique)) {
        final snap = await firestore
            .collection(FirestoreCollections.users)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final raw = doc.data()['name'];
          final name = raw is String ? raw.trim() : '';
          if (name.isNotEmpty) names[doc.id] = name;
        }
      }
      return names;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AbsenceRequestModel>> getAbsenceRequestsForHalaqatOnDate({
    required List<String> halaqaIds,
    required DateTime date,
  }) async {
    try {
      final items = <AbsenceRequestModel>[];
      for (final rawId in halaqaIds) {
        items.addAll(
          await AbsenceRequestFirestoreReads.forHalaqaOnDate(
            firestore: firestore,
            halaqaId: rawId,
            date: date,
            pendingOnly: false,
          ),
        );
      }
      AbsenceRequestFirestoreReads.sortSupervisorDay(items);
      return items;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
