import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/academy_admission_firestore.dart';
import '../../../../shared/data/academy_halaqa_firestore.dart';
import '../../../../shared/data/achievements_firestore_contract.dart';
import '../../../../shared/data/admin_communication_settings_contract.dart';
import '../../../../shared/data/admin_internal_chat_firestore.dart';
import '../../../../shared/utils/firestore_in_query.dart';
import '../../domain/admin_grant_reward_params.dart';
import '../../domain/admin_ops_broadcast.dart';
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/admin_directory_entity.dart';
import '../../domain/entities/admin_halaqa_roster_entity.dart';
import '../../domain/entities/communication_settings_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/admin_payment_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../../domain/entities/teacher_activity_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';
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
        // Academy-wide attendance % requires server aggregation (not in functions/).
        overallAttendancePercent: 0,
        totalVersesMemorizedThisMonth: 0,
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
  Future<List<AdminPaymentEntity>> getPayments() async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.payments)
          .get();

      final payments = snap.docs.map((doc) {
        final data = doc.data();
        final dueRaw = data['dueDate'];
        final paidRaw = data['paidAt'];
        return AdminPaymentEntity(
          id: doc.id,
          studentId: data['studentId'] as String? ?? '',
          parentId: data['parentId'] as String? ?? '',
          amount: (data['amount'] ?? 0).toDouble(),
          status: data['status'] as String? ?? 'due',
          dueDate: dueRaw is Timestamp ? dueRaw.toDate() : null,
          paidAt: paidRaw is Timestamp ? paidRaw.toDate() : null,
          method: data['method'] as String?,
        );
      }).toList();

      payments.sort((a, b) {
        final aDate = a.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return payments;
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
      await AcademyAdmissionFirestore.establishMembership(
        firestore: firestore,
        studentId: studentId,
        halaqaId: halaqaId,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      if (e is ServerException) rethrow;
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

  ComplaintEntity _complaintFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final createdRaw = data['createdAt'];
    final updatedRaw = data['updatedAt'];
    return ComplaintEntity(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderRole: data['senderRole'] ?? '',
      subject: data['subject'] ?? '',
      message: data['message'] ?? '',
      status: data['status'] ?? ComplaintStatuses.open,
      response: data['response'] as String?,
      createdAt: createdRaw is Timestamp
          ? createdRaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      priority: data['priority'] as String? ?? ComplaintPriorities.normal,
      assigneeId: data['assigneeId'] as String?,
      assigneeRole: data['assigneeRole'] as String?,
      updatedAt: updatedRaw is Timestamp ? updatedRaw.toDate() : null,
    );
  }

  @override
  Future<List<ComplaintEntity>> getComplaints() async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.complaints)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map(_complaintFromDoc).toList();
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
      await updateComplaint(
        complaintId: complaintId,
        response: response,
        status: ComplaintStatuses.resolved,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateComplaint({
    required String complaintId,
    String? status,
    String? priority,
    String? assigneeId,
    String? assigneeRole,
    String? response,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (status != null) updates['status'] = status;
      if (priority != null) updates['priority'] = priority;
      if (assigneeId != null) updates['assigneeId'] = assigneeId;
      if (assigneeRole != null) updates['assigneeRole'] = assigneeRole;
      if (response != null) updates['response'] = response;

      await firestore
          .collection(FirestoreCollections.complaints)
          .doc(complaintId)
          .update(updates);
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
        ...AdminOpsBroadcast.notificationFields(
          title: title,
          body: body,
          targetRole: targetRole,
        ),
        AdminOpsBroadcast.createdAtField: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<TeacherManagementEntity>> getAllTeachers() async {
    try {
      final usersSnap = await firestore
          .collection(FirestoreCollections.users)
          .where('role', isEqualTo: AppRoles.teacher)
          .get();

      if (usersSnap.docs.isEmpty) return [];

      final profileFutures = usersSnap.docs.map((userDoc) {
        return firestore
            .collection(FirestoreCollections.teacherProfiles)
            .doc(userDoc.id)
            .get();
      });

      final profileDocs = await Future.wait(profileFutures);

      return List.generate(usersSnap.docs.length, (i) {
        final userData = usersSnap.docs[i].data();
        final profileData = profileDocs[i].data();

        return TeacherManagementEntity(
          uid: usersSnap.docs[i].id,
          name: userData['name'] ?? '',
          profileImageUrl: userData['profileImageUrl'] as String?,
          halaqatIds: List<String>.from(profileData?['halaqatIds'] ?? const []),
          performanceRating: (profileData?['performanceRating'] as num?)
              ?.toDouble(),
          weeklyQuota: (profileData?['weeklyQuota'] ?? 0) as int,
          isActive: userData['isActive'] as bool? ?? true,
        );
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateTeacherPerformance({
    required String teacherId,
    required double rating,
  }) async {
    try {
      await firestore
          .collection(FirestoreCollections.teacherProfiles)
          .doc(teacherId)
          .update({'performanceRating': rating});
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateTeacherQuota({
    required String teacherId,
    required int weeklyQuota,
  }) async {
    try {
      await firestore
          .collection(FirestoreCollections.teacherProfiles)
          .doc(teacherId)
          .update({'weeklyQuota': weeklyQuota});
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TeacherActivityEntity> getTeacherActivityLog({
    required String teacherId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.attendanceRecords)
          .where('recordedBy', isEqualTo: teacherId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .get();

      final uniqueDates = <DateTime>{};
      for (final doc in snapshot.docs) {
        final timestamp = (doc.data())['date'] as Timestamp;
        final date = timestamp.toDate();
        uniqueDates.add(DateTime(date.year, date.month, date.day));
      }

      final sortedDates = uniqueDates.toList()..sort();

      return TeacherActivityEntity(
        teacherId: teacherId,
        rangeStart: from,
        rangeEnd: to,
        activeDates: sortedDates,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadUsersByIds(
    Iterable<String> ids,
  ) async {
    final unique = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (unique.isEmpty) return const {};

    final out = <String, Map<String, dynamic>>{};
    for (final chunk in FirestoreInQuery.chunkIds(unique)) {
      final snap = await firestore
          .collection(FirestoreCollections.users)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        out[doc.id] = doc.data();
      }
    }
    return out;
  }

  @override
  Future<List<AdminHalaqaRosterEntity>> getAcademyStudentRoster() async {
    try {
      final halaqaSnap = await firestore
          .collection(FirestoreCollections.halaqat)
          .get();

      final roster = <AdminHalaqaRosterEntity>[];
      for (final hDoc in halaqaSnap.docs) {
        final hData = hDoc.data();
        final studentIds = List<String>.from(hData['studentIds'] ?? const []);
        final users = await _loadUsersByIds(studentIds);

        final students = studentIds.map((sid) {
          final u = users[sid] ?? const <String, dynamic>{};
          return AdminRosterStudentEntity(
            uid: sid,
            name: u['name'] as String? ?? sid,
            phone: u['phone'] as String?,
            profileImageUrl: u['profileImageUrl'] as String?,
            isActive: u['isActive'] as bool? ?? true,
          );
        }).toList()..sort((a, b) => a.name.compareTo(b.name));

        roster.add(
          AdminHalaqaRosterEntity(
            id: hDoc.id,
            name: hData['name'] as String? ?? hDoc.id,
            teacherId: hData['teacherId'] as String? ?? '',
            supervisorId: hData['supervisorId'] as String? ?? '',
            status: hData['status'] as String? ?? 'active',
            students: students,
          ),
        );
      }

      roster.sort((a, b) => a.name.compareTo(b.name));
      return roster;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<RegistrationRequestEntity>> getRegistrationRequests() async {
    try {
      final usersSnap = await firestore
          .collection(FirestoreCollections.users)
          .where('role', isEqualTo: AppRoles.student)
          .where('isActive', isEqualTo: true)
          .get();

      if (usersSnap.docs.isEmpty) return const [];

      final pending = <RegistrationRequestEntity>[];
      for (final userDoc in usersSnap.docs) {
        final profileSnap = await firestore
            .collection(FirestoreCollections.studentProfiles)
            .doc(userDoc.id)
            .get();
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final halaqaId = profileData['halaqaId'] as String?;
        if (halaqaId != null && halaqaId.trim().isNotEmpty) continue;

        final userData = userDoc.data();
        final createdRaw = userData['createdAt'] ?? profileData['createdAt'];
        pending.add(
          RegistrationRequestEntity(
            studentId: userDoc.id,
            name: userData['name'] as String? ?? userDoc.id,
            phone: userData['phone'] as String?,
            email: userData['email'] as String?,
            profileImageUrl: userData['profileImageUrl'] as String?,
            registeredAt: createdRaw is Timestamp ? createdRaw.toDate() : null,
          ),
        );
      }

      pending.sort((a, b) => a.name.compareTo(b.name));
      return pending;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> rejectRegistrationRequest({required String studentId}) async {
    try {
      await firestore
          .collection(FirestoreCollections.users)
          .doc(studentId.trim())
          .update({'isActive': false});
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> approveRegistrationRequest({
    required String studentId,
    required String halaqaId,
    String? teacherId,
    String? supervisorId,
  }) async {
    try {
      await AcademyHalaqaFirestore.assignStaff(
        firestore: firestore,
        halaqaId: halaqaId,
        teacherId: teacherId,
        supervisorId: supervisorId,
      );
      await AcademyAdmissionFirestore.establishMembership(
        firestore: firestore,
        studentId: studentId,
        halaqaId: halaqaId,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AdminHalaqaSummaryEntity>> getAllHalaqat() async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.halaqat)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        final studentIds = List<String>.from(data['studentIds'] ?? const []);
        return AdminHalaqaSummaryEntity(
          id: doc.id,
          name: data['name'] as String? ?? doc.id,
          teacherId: data['teacherId'] as String? ?? '',
          supervisorId: data['supervisorId'] as String? ?? '',
          studentCount: studentIds.length,
        );
      }).toList()..sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AdminStaffSummaryEntity>> getAllSupervisors() async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.users)
          .where('role', isEqualTo: AppRoles.supervisor)
          .where('isActive', isEqualTo: true)
          .get();
      return snap.docs
          .map(
            (doc) => AdminStaffSummaryEntity(
              uid: doc.id,
              name: doc.data()['name'] as String? ?? doc.id,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<CommunicationSettingsEntity> getCommunicationSettings() async {
    try {
      final doc = await firestore
          .doc(AdminCommunicationSettingsContract.docPath)
          .get();
      if (!doc.exists) return CommunicationSettingsEntity.defaults();

      final data = doc.data() ?? AdminCommunicationSettingsContract.defaults();
      return CommunicationSettingsEntity(
        autoReplyOutsideHours:
            data[AdminCommunicationSettingsContract.autoReplyOutsideHoursField]
                as bool? ??
            true,
        broadcastsNeedApproval:
            data[AdminCommunicationSettingsContract.broadcastsNeedApprovalField]
                as bool? ??
            true,
        maxFileSizeMb:
            (data[AdminCommunicationSettingsContract.maxFileSizeMbField]
                    as num?)
                ?.toInt() ??
            25,
        allowedFileTypes:
            data[AdminCommunicationSettingsContract.allowedFileTypesField]
                as String? ??
            'PDF, JPG, MP3, MP4',
        conversationRetentionDays:
            (data[AdminCommunicationSettingsContract
                        .conversationRetentionDaysField]
                    as num?)
                ?.toInt() ??
            365,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> saveCommunicationSettings(
    CommunicationSettingsEntity settings,
  ) async {
    try {
      await firestore.doc(AdminCommunicationSettingsContract.docPath).set({
        AdminCommunicationSettingsContract.autoReplyOutsideHoursField:
            settings.autoReplyOutsideHours,
        AdminCommunicationSettingsContract.broadcastsNeedApprovalField:
            settings.broadcastsNeedApproval,
        AdminCommunicationSettingsContract.maxFileSizeMbField:
            settings.maxFileSizeMb,
        AdminCommunicationSettingsContract.allowedFileTypesField:
            settings.allowedFileTypes,
        AdminCommunicationSettingsContract.conversationRetentionDaysField:
            settings.conversationRetentionDays,
        AdminCommunicationSettingsContract.updatedAtField:
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> grantReward(AdminGrantRewardParams params) async {
    try {
      if (params.targetKind == AdminRewardTargetKind.student) {
        await firestore
            .collection(FirestoreCollections.achievements)
            .add(
              AchievementsFirestoreContract.teacherGrantFields(
                studentId: params.targetId,
                studentName: params.studentName ?? '',
                type: params.type.trim(),
                title: params.title.trim(),
                description: params.description,
                grantedBy: params.grantedBy,
                halaqaId: params.halaqaId ?? '',
                halaqaName: params.halaqaName,
              ),
            );
        return;
      }

      final halaqaDoc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(params.targetId.trim())
          .get();
      if (!halaqaDoc.exists) {
        throw const ServerException('الحلقة غير موجودة');
      }
      final hData = halaqaDoc.data() ?? const <String, dynamic>{};
      final studentIds = List<String>.from(
        hData['studentIds'] ?? const <String>[],
      );
      if (studentIds.isEmpty) {
        throw const ServerException('لا يوجد طلاب في هذه الحلقة');
      }

      final users = await _loadUsersByIds(studentIds);
      final halaqaName = hData['name'] as String? ?? '';
      final batch = firestore.batch();
      for (final sid in studentIds) {
        final u = users[sid] ?? const <String, dynamic>{};
        final ref = firestore
            .collection(FirestoreCollections.achievements)
            .doc();
        batch.set(
          ref,
          AchievementsFirestoreContract.teacherGrantFields(
            studentId: sid,
            studentName: u['name'] as String? ?? sid,
            type: params.type.trim(),
            title: params.title.trim(),
            description: params.description,
            grantedBy: params.grantedBy,
            halaqaId: params.targetId,
            halaqaName: halaqaName,
            halaqaIds: [params.targetId],
            halaqaNames: halaqaName.isEmpty ? const [] : [halaqaName],
            recipientStudentIds: studentIds,
            recipientCount: studentIds.length,
          ),
        );
      }
      await batch.commit();
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> createHalaqa({
    required String name,
    required String teacherId,
    required String supervisorId,
    String meetingLink = '',
  }) async {
    try {
      return AcademyHalaqaFirestore.createHalaqa(
        firestore: firestore,
        name: name,
        teacherId: teacherId,
        supervisorId: supervisorId,
        meetingLink: meetingLink,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> ensureAdminInternalChat({required String adminUid}) async {
    try {
      return AdminInternalChatFirestore.ensureConversation(
        firestore: firestore,
        currentAdminUid: adminUid,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
