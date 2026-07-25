import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../domain/entities/parent_entities.dart';
import '../models/parent_model.dart';

@LazySingleton(as: ParentRemoteDatasource)
class ParentRemoteDatasourceImpl implements ParentRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const ParentRemoteDatasourceImpl({
    required this.firestore,
    required this.functions,
  });

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

      // نجيب حضور الأسبوع
      final attendanceSnap = await firestore
          .collection(FirestoreCollections.attendanceRecords)
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('date', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      // نجيب تسميعات الأسبوع
      final recitationSnap = await firestore
          .collection(FirestoreCollections.recitationRecords)
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('date', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      // نجيب اسم الطالب
      final userDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(studentId)
          .get();

      final studentName = (userDoc.data())?['name'] ?? '';

      final statuses = AttendancePolicy.uniqueDayStatuses(
        attendanceSnap.docs.map((d) {
          final data = d.data();
          final rawDate = data['date'];
          final date = rawDate is Timestamp
              ? rawDate.toDate()
              : (rawDate as DateTime? ?? weekStart);
          return AttendanceMarkRef(
            id: d.id,
            halaqaId: (data['halaqaId'] as String?) ?? '',
            studentId: studentId,
            date: date,
            status: data['status'] as String?,
          );
        }),
      );
      final attended = AttendancePolicy.countAttended(statuses);

      // D6 / Slice 5: count and surface only reviewed recitations — pending
      // homework submits are not final parent-facing activity.
      final reviewedDocs =
          recitationSnap.docs.where((d) {
            final status = d.data()['reviewStatus'] as String? ?? 'reviewed';
            return status != 'pending';
          }).toList()..sort((a, b) {
            final ad =
                (a.data()['date'] as Timestamp?)?.toDate() ?? DateTime(0);
            final bd =
                (b.data()['date'] as Timestamp?)?.toDate() ?? DateTime(0);
            return ad.compareTo(bd);
          });

      var lastNote = reviewedDocs.isNotEmpty
          ? (reviewedDocs.last.data())['notes'] as String? ?? ''
          : '';
      // Student-submit placeholder is not a teacher note.
      if (lastNote.contains('بانتظار المراجعة')) {
        lastNote = '';
      }

      return WeeklyReportModel.fromMap(
        studentId: studentId,
        studentName: studentName,
        weekStart: weekStart,
        data: {
          'totalVersesMemorized': reviewedDocs.length,
          'attendedSessions': attended,
          'totalSessions': statuses.length,
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

  @override
  Future<PaymentInitiationEntity> initiatePayment(String paymentId) async {
    throw const ServerException(
      'الدفع الإلكتروني غير متاح حالياً، سيتم تفعيله قريباً',
    ); // try {
    //   final callable = functions.httpsCallable('createPaymentIntention');
    //   final result = await callable.call<Map<String, dynamic>>({
    //     'paymentId': paymentId,
    //   });
    //
    //   final data = result.data;
    //   return PaymentInitiationEntity(
    //     clientSecret: data['clientSecret'] as String,
    //     publicKey: data['publicKey'] as String,
    //   );
    // } on FirebaseFunctionsException catch (e) {
    //   // رسائل الـ HttpsError اللي بعتناها من الـ Cloud Function (زي
    //   // "تم سداد هذه الدفعة بالفعل") بتوصل هنا في e.message.
    //   throw ServerException(e.message ?? 'تعذر بدء عملية الدفع');
    // } catch (e) {
    //   throw ServerException(e.toString());
    // }
  }
}
