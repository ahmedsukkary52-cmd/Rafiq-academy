import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/academy_admission_firestore.dart';
import '../../../../shared/domain/academy_billing_entities.dart';
import '../../../../shared/domain/academy_payment_settings_contract.dart';
import '../../../../shared/domain/pricing_rules_contract.dart';
import '../../domain/admin_ops_broadcast.dart';
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../../domain/entities/teacher_activity_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';
import 'admin_remote_datasource.dart';

@LazySingleton(as: AdminRemoteDatasource)
class AdminRemoteDatasourceImpl implements AdminRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const AdminRemoteDatasourceImpl({
    required this.firestore,
    required this.functions,
  });

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
      await AcademyAdmissionFirestore.establishMembership(
        firestore: firestore,
        studentId: studentId,
        halaqaId: halaqaId,
      );
    } on ServerException {
      rethrow;
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

  /// Admin ops broadcast — **not** [AcademyEventSink] (H3 / A-H15 quarantine).
  ///
  /// Role/`all` audience fan-out via `notifications.add`. Schema owned by
  /// [AdminOpsBroadcast]; do not route through W4/W5 academy facts.
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
      // الخطوة 1: نجيب كل المستخدمين اللي دورهم "معلم" (للاسم والصورة)
      final usersSnap = await firestore
          .collection(FirestoreCollections.users)
          .where('role', isEqualTo: AppRoles.teacher)
          .get();

      if (usersSnap.docs.isEmpty) return [];

      // الخطوة 2: نجيب بروفايل كل معلم (النصاب والتقييم) بالتوازي.
      // ملاحظة: ده N قراءة منفصلة بعدد المعلمين (مش query واحد)، لأن
      // Firestore مفيهوش joins. مقبول طالما عدد المعلمين بالعشرات،
      // لو الأكاديمية كبرت جداً (مئات المعلمين) هنحتاج نفكر في تجميع
      // البيانات دي مسبقاً (denormalization) بدل القراءة المباشرة.
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

      // بنحوّل كل تاريخ لـ "يوم بس" (من غير وقت) ونشيل التكرار، عشان
      // لو المعلم سجّل حضور لأكتر من طالب في نفس اليوم، يحسب يوم واحد
      // بس في سجل النشاط مش يتكرر بعدد الطلاب.
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
    String? phone,
    bool isActive = true,
  }) async {
    try {
      final callable = functions.httpsCallable('adminProvisionUser');
      final result = await callable.call(<String, dynamic>{
        'email': email.trim(),
        'password': password,
        'name': name.trim(),
        'role': role.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
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
}
