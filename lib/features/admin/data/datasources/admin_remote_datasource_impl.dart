import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
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

  const AdminRemoteDatasourceImpl({required this.firestore});

  @override
  Future<AcademyStatsEntity> getAcademyStats() async {
    try {
      final results = await Future.wait([
        firestore.collection(FirestoreCollections.users)
            .where('role', isEqualTo: AppRoles.student)
            .where('isActive', isEqualTo: true)
            .count().get(),
        firestore.collection(FirestoreCollections.users)
            .where('role', isEqualTo: AppRoles.teacher)
            .where('isActive', isEqualTo: true)
            .count().get(),
        firestore.collection(FirestoreCollections.halaqat)
            .where('status', isEqualTo: 'active')
            .count().get(),
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
        firestore.collection(FirestoreCollections.studentProfiles).doc(
            studentId),
        {'halaqaId': halaqaId},
      );
      batch.update(
        firestore.collection(FirestoreCollections.halaqat).doc(halaqaId),
        {'studentIds': FieldValue.arrayUnion([studentId])},
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
      await firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .update({'isActive': isActive});
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
          halaqatIds:
          List<String>.from(profileData?['halaqatIds'] ?? const []),
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

      final sortedDates = uniqueDates.toList()
        ..sort();

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
}
