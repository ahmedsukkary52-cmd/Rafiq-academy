import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/admin_communication_settings_contract.dart';
import '../../../../shared/domain/academy_billing_entities.dart';
import '../../../../shared/domain/academy_payment_settings_contract.dart';
import '../../../../shared/domain/pricing_rules_contract.dart';
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
import '../../../awards/data/award_grant_errors.dart';
import '../../../awards/domain/award_submission_id.dart';
import '../admin_private_email_reader.dart';
import '../communication_settings_errors.dart';
import 'admin_remote_datasource.dart';

@LazySingleton(as: AdminRemoteDatasource)
class AdminRemoteDatasourceImpl implements AdminRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const AdminRemoteDatasourceImpl({
    required this.firestore,
    required this.functions,
  });

  AdminPrivateEmailReader get emailReader => AdminPrivateEmailReader(firestore);

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
      final callable = functions.httpsCallable('admitStudentToHalaqa');
      await callable.call(<String, dynamic>{
        'halaqaId': halaqaId.trim(),
        'studentId': studentId.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'already-exists') {
        throw ServerException(e.message ?? e.code);
      }
      // Already on this roster: approval only (re)activates the account.
      await toggleAccountStatus(uid: studentId.trim(), isActive: true);
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

  @override
  Future<String> provisionUser({
    required String email,
    required String password,
    required String name,
    required String role,
    bool isActive = true,
  }) async {
    try {
      final callable = functions.httpsCallable('adminProvisionUser');
      final result = await callable.call(<String, dynamic>{
        'email': email.trim(),
        'password': password,
        'name': name.trim(),
        'role': role.trim(),
        'isActive': isActive,
      });
      final data = result.data;
      if (data is Map) {
        final uid = data['uid'];
        if (uid is String && uid.isNotEmpty) return uid;
      }
      throw const ServerException('تعذر إنشاء الحساب: رد غير متوقع');
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PaymentPublicSettingsEntity> getPaymentPublicSettings() async {
    try {
      final doc = await firestore
          .collection(FirestoreCollections.academySettings)
          .doc(AcademyPaymentSettingsContract.paymentPublicDocId)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final updated = data[AcademyPaymentSettingsContract.updatedAtField];
      return PaymentPublicSettingsEntity(
        vodafoneCashDestination:
            (data[AcademyPaymentSettingsContract.vodafoneCashDestinationField]
                    as String?)
                ?.trim() ??
            '',
        updatedAt: updated is Timestamp ? updated.toDate() : null,
        updatedBy:
            data[AcademyPaymentSettingsContract.updatedByField] as String?,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updatePaymentPublicSettings({
    required String vodafoneCashDestination,
  }) async {
    try {
      final uid = FirebaseAuth.instanceFor(app: firestore.app).currentUser?.uid;
      await firestore
          .collection(FirestoreCollections.academySettings)
          .doc(AcademyPaymentSettingsContract.paymentPublicDocId)
          .set({
            AcademyPaymentSettingsContract.vodafoneCashDestinationField:
                vodafoneCashDestination.trim(),
            AcademyPaymentSettingsContract.updatedAtField:
                FieldValue.serverTimestamp(),
            AcademyPaymentSettingsContract.updatedByField: uid,
          }, SetOptions(merge: true));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PricingDefaultsEntity> getPricingDefaults() async {
    try {
      final doc = await firestore
          .collection(FirestoreCollections.academySettings)
          .doc(AcademyPaymentSettingsContract.pricingDefaultsDocId)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final updated = data[AcademyPaymentSettingsContract.updatedAtField];
      return PricingDefaultsEntity(
        gracePeriodDays:
            (data[AcademyPaymentSettingsContract.gracePeriodDaysField] as num?)
                ?.toInt() ??
            AcademyPaymentSettingsContract.defaultGracePeriodDays,
        defaultCurrency:
            (data[AcademyPaymentSettingsContract.defaultCurrencyField]
                as String?) ??
            AcademyPaymentSettingsContract.defaultCurrency,
        defaultBillingPeriod:
            (data[AcademyPaymentSettingsContract.defaultBillingPeriodField]
                as String?) ??
            AcademyPaymentSettingsContract.defaultBillingPeriod,
        updatedAt: updated is Timestamp ? updated.toDate() : null,
        updatedBy:
            data[AcademyPaymentSettingsContract.updatedByField] as String?,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updatePricingDefaults({
    required int gracePeriodDays,
    required String defaultCurrency,
    required String defaultBillingPeriod,
  }) async {
    try {
      if (gracePeriodDays < 0) {
        throw const ServerException('gracePeriodDays يجب أن يكون ≥ 0');
      }
      final uid = FirebaseAuth.instanceFor(app: firestore.app).currentUser?.uid;
      await firestore
          .collection(FirestoreCollections.academySettings)
          .doc(AcademyPaymentSettingsContract.pricingDefaultsDocId)
          .set({
            AcademyPaymentSettingsContract.gracePeriodDaysField:
                gracePeriodDays,
            AcademyPaymentSettingsContract.defaultCurrencyField: defaultCurrency
                .trim(),
            AcademyPaymentSettingsContract.defaultBillingPeriodField:
                defaultBillingPeriod.trim(),
            AcademyPaymentSettingsContract.updatedAtField:
                FieldValue.serverTimestamp(),
            AcademyPaymentSettingsContract.updatedByField: uid,
          }, SetOptions(merge: true));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<PricingRuleEntity>> listPricingRules() async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.pricingRules)
          .get();
      return snap.docs.map(_mapPricingRule).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  PricingRuleEntity _mapPricingRule(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return PricingRuleEntity(
      id: doc.id,
      scope:
          (data[PricingRulesContract.scopeField] as String?) ??
          PricingRulesContract.scopeAcademyDefault,
      scopeId: data[PricingRulesContract.scopeIdField] as String?,
      amount: (data[PricingRulesContract.amountField] as num?)?.toDouble() ?? 0,
      currency:
          (data[PricingRulesContract.currencyField] as String?) ??
          AcademyPaymentSettingsContract.defaultCurrency,
      billingPeriod:
          (data[PricingRulesContract.billingPeriodField] as String?) ??
          AcademyPaymentSettingsContract.defaultBillingPeriod,
      active: data[PricingRulesContract.activeField] as bool? ?? true,
      version: (data[PricingRulesContract.versionField] as num?)?.toInt() ?? 1,
      effectiveFrom: ts(data[PricingRulesContract.effectiveFromField]),
      effectiveTo: ts(data[PricingRulesContract.effectiveToField]),
      updatedAt: ts(data[PricingRulesContract.updatedAtField]),
      updatedBy: data[PricingRulesContract.updatedByField] as String?,
    );
  }

  @override
  Future<void> upsertPricingRule(PricingRuleEntity rule) async {
    try {
      if (rule.amount <= 0) {
        throw const ServerException(
          'مبلغ قاعدة التسعير يجب أن يكون أكبر من صفر',
        );
      }
      final uid = FirebaseAuth.instanceFor(app: firestore.app).currentUser?.uid;
      final id = rule.id.trim().isEmpty
          ? firestore.collection(FirestoreCollections.pricingRules).doc().id
          : rule.id.trim();
      final existing = await firestore
          .collection(FirestoreCollections.pricingRules)
          .doc(id)
          .get();
      final nextVersion = existing.exists
          ? ((existing.data()?[PricingRulesContract.versionField] as num?)
                        ?.toInt() ??
                    0) +
                1
          : rule.version;
      await firestore
          .collection(FirestoreCollections.pricingRules)
          .doc(id)
          .set({
            PricingRulesContract.scopeField: rule.scope,
            PricingRulesContract.scopeIdField: rule.scopeId,
            PricingRulesContract.amountField: rule.amount,
            PricingRulesContract.currencyField: rule.currency,
            PricingRulesContract.billingPeriodField: rule.billingPeriod,
            PricingRulesContract.activeField: rule.active,
            PricingRulesContract.versionField: nextVersion,
            PricingRulesContract.updatedAtField: FieldValue.serverTimestamp(),
            PricingRulesContract.updatedByField: uid,
            if (!existing.exists)
              PricingRulesContract.createdAtField: FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> generateInvoice({
    required String studentId,
    String? parentId,
    String? periodKey,
    String? pricingRuleId,
  }) async {
    try {
      final callable = functions.httpsCallable('adminGenerateInvoice');
      final result = await callable.call(<String, dynamic>{
        'studentId': studentId.trim(),
        if (parentId != null && parentId.trim().isNotEmpty)
          'parentId': parentId.trim(),
        if (periodKey != null && periodKey.trim().isNotEmpty)
          'periodKey': periodKey.trim(),
        if (pricingRuleId != null && pricingRuleId.trim().isNotEmpty)
          'pricingRuleId': pricingRuleId.trim(),
      });
      final data = result.data;
      if (data is Map && data['paymentId'] is String) {
        return data['paymentId'] as String;
      }
      throw const ServerException('تعذر إنشاء الفاتورة: رد غير متوقع');
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
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
        final privateEmail = await emailReader.emailOf(userDoc.id);
        pending.add(
          RegistrationRequestEntity(
            studentId: userDoc.id,
            name: userData['name'] as String? ?? userDoc.id,
            email: AdminPrivateEmailReader.preferPrivate(
              privateEmail,
              userData['email'],
            ),
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
      // Halaqa staff is server-owned (no staff-assignment callable exists),
      // so admission only accepts the halaqa's current teacher/supervisor.
      final halaqaDoc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId.trim())
          .get();
      if (!halaqaDoc.exists) {
        throw const ServerException('الحلقة غير موجودة');
      }
      final hData = halaqaDoc.data() ?? const <String, dynamic>{};
      bool differs(String? requested, String field) {
        final wanted = requested?.trim() ?? '';
        return wanted.isNotEmpty &&
            wanted != ((hData[field] as String?)?.trim() ?? '');
      }

      if (differs(teacherId, 'teacherId') ||
          differs(supervisorId, 'supervisorId')) {
        throw const ServerException(
          'تغيير معلم أو مشرف الحلقة غير متاح من هنا. اختر الحلقة المناسبة.',
        );
      }
      await approveNewStudent(studentId: studentId, halaqaId: halaqaId);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> reinstatePaymentAccess({
    required String parentId,
    String? reason,
  }) async {
    try {
      final callable = functions.httpsCallable('adminReinstatePaymentAccess');
      await callable.call(<String, dynamic>{
        'parentId': parentId.trim(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
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
      // Server only: a cached (or cached-missing) doc would let a later save
      // write stale values or defaults over the real settings.
      final doc = await firestore
          .doc(AdminCommunicationSettingsContract.docPath)
          .get(const GetOptions(source: Source.server));
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
    } on FirebaseException catch (e) {
      throw ServerException(
        communicationSettingsErrorMessage(e.code, save: false),
      );
    } catch (_) {
      throw const ServerException(kCommunicationSettingsLoadFailedMessage);
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
    } on FirebaseException catch (e) {
      throw ServerException(
        communicationSettingsErrorMessage(e.code, save: true),
      );
    } catch (_) {
      throw const ServerException(kCommunicationSettingsSaveFailedMessage);
    }
  }

  /// Admin reward chips → `grantAward` AWARD_TYPE_KEYS.
  static const Map<String, String> _rewardTypeKeys = {
    'star': 'performance_stars',
    'badge': 'completion_badge',
    'certificate': 'achievement',
  };

  @override
  Future<void> grantReward(AdminGrantRewardParams params) async {
    var requestSent = false;
    try {
      if (!AwardSubmissionId.isValid(params.awardId)) {
        throw const ServerException(kAwardGrantFailedMessage);
      }
      // Sent exactly as pinned: re-reading the roster here would change the
      // request behind an operation id the server may already have committed.
      final halaqaId = params.halaqaId?.trim() ?? '';
      final recipients = params.recipientStudentIds;
      if (halaqaId.isEmpty || recipients.isEmpty) {
        throw const ServerException(kAwardGrantFailedMessage);
      }

      final type = params.type.trim();
      final callable = functions.httpsCallable('grantAward');
      requestSent = true;
      await callable.call(<String, dynamic>{
        'awardId': params.awardId,
        'type': _rewardTypeKeys[type] ?? type,
        'title': params.title.trim(),
        'description': params.description?.trim() ?? '',
        'studentName': params.studentName ?? '',
        'halaqaId': halaqaId,
        'halaqaIds': [halaqaId],
        'recipientStudentIds': recipients,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(awardGrantErrorMessage(e.code, e.message));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        awardGrantUnexpectedErrorMessage(requestSent: requestSent),
      );
    }
  }

  @override
  Future<String> ensureAdminInternalChat({required String adminUid}) async {
    // Conversations are callable-created only, and no callable creates the
    // multi-admin group yet.
    throw const ServerException('مجموعة الإدارة الداخلية غير متاحة حاليًا');
  }
}
