import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import 'admin_remote_datasource.dart';

@LazySingleton(as: AdminRemoteDatasource)
class AdminRemoteDatasourceImpl implements AdminRemoteDatasource {
  final FirebaseFirestore firestore;

  const AdminRemoteDatasourceImpl({required this.firestore});

  @override
  Future<AcademyStatsEntity> getAcademyStats() async {
    try {
      final results = await Future.wait([
        firestore
            .collection(FirestoreCollections.users)
            .where('role', isEqualTo: AppRoles.student)
            .where('isActive', isEqualTo: true)
            .count()
            .get(),
        firestore
            .collection(FirestoreCollections.users)
            .where('role', isEqualTo: AppRoles.teacher)
            .where('isActive', isEqualTo: true)
            .count()
            .get(),
        firestore
            .collection(FirestoreCollections.halaqat)
            .where('status', isEqualTo: 'active')
            .count()
            .get(),
      ]);

      return AcademyStatsEntity(
        totalStudents: results[0].count ?? 0,
        totalTeachers: results[1].count ?? 0,
        totalHalaqat: results[2].count ?? 0,
        overallAttendancePercent: 0,
        // يتحسب بـ Cloud Function
        totalVersesMemorizedThisMonth: 0, // يتحسب بـ Cloud Function
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<FinancialSummaryEntity> getFinancialSummary() async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.payments)
          .get();

      double revenue = 0, pending = 0, overdue = 0;
      int paidCount = 0, dueCount = 0, overdueCount = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final status = data['status'] as String? ?? '';

        switch (status) {
          case 'paid':
            revenue += amount;
            paidCount++;
          case 'due':
            pending += amount;
            dueCount++;
          case 'overdue':
            overdue += amount;
            overdueCount++;
        }
      }

      return FinancialSummaryEntity(
        totalRevenue: revenue,
        totalPending: pending,
        totalOverdue: overdue,
        paidCount: paidCount,
        dueCount: dueCount,
        overdueCount: overdueCount,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> approveNewStudent({
    required String studentId,
    required String halaqaId,
  }) async {
    try {
      final batch = firestore.batch();

      batch.update(
        firestore.collection(FirestoreCollections.users).doc(studentId),
        {'isActive': true},
      );
      batch.update(
        firestore
            .collection(FirestoreCollections.studentProfiles)
            .doc(studentId),
        {'halaqaId': halaqaId},
      );
      batch.update(
        firestore.collection(FirestoreCollections.halaqat).doc(halaqaId),
        {
          'studentIds': FieldValue.arrayUnion([studentId]),
        },
      );

      await batch.commit();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> toggleAccountStatus({
    required String uid,
    required bool isActive,
  }) async {
    try {
      await firestore.collection(FirestoreCollections.users).doc(uid).update({
        'isActive': isActive,
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ComplaintEntity>> getComplaints() async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.complaints)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return ComplaintEntity(
          id: doc.id,
          senderId: data['senderId'] ?? '',
          senderRole: data['senderRole'] ?? '',
          subject: data['subject'] ?? '',
          message: data['message'] ?? '',
          status: data['status'] ?? 'open',
          response: data['response'] as String?,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
        );
      }).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> respondToComplaint({
    required String complaintId,
    required String response,
  }) async {
    try {
      await firestore
          .collection(FirestoreCollections.complaints)
          .doc(complaintId)
          .update({'response': response, 'status': 'resolved'});
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    required String targetRole,
  }) async {
    try {
      await firestore.collection(FirestoreCollections.notifications).add({
        'recipientId': 'all',
        'recipientRole': targetRole,
        'title': title,
        'body': body,
        'type': NotificationTypes.general,
        'isRead': false,
        'hasAudioAlert': false,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
