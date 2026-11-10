import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/absence_request_firestore_reads.dart';
import '../../../../shared/data/payment_public_settings_mapper.dart';
import '../../../../shared/domain/academy_billing_entities.dart';
import '../../../../shared/domain/academy_payment_settings_contract.dart';
import '../../../../shared/domain/payment_access_contract.dart';
import '../../../../shared/domain/payment_access_entity.dart';
import '../../../../shared/domain/student_at_risk_policy.dart';
import '../../../../shared/domain/upload_file_policy.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../analytics/domain/analytics_recitation_honesty.dart';
import '../../../../shared/data/models/achievement_model.dart';
import '../../../../shared/domain/recitation_record_entity.dart';
import '../../domain/parent_household.dart';
import '../../../../shared/domain/parent_payment_proof.dart';
import '../../domain/services/parent_recipient_resolver.dart';
import '../models/parent_model.dart';
import '../parent_achievements_response.dart';

@LazySingleton(as: ParentRemoteDatasource)
class ParentRemoteDatasourceImpl implements ParentRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final FirebaseFunctions functions;
  final UnconfirmedProofUploads _unconfirmedUploads = UnconfirmedProofUploads();

  ParentRemoteDatasourceImpl({
    required this.firestore,
    required this.storage,
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
  Future<Map<String, List<String>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) async {
    try {
      final requested = ParentRecipientResolver.normalizeStudentIds(studentIds);
      if (requested.isEmpty) return {};

      final requestedSet = requested.toSet();
      final result = <String, List<String>>{};
      final chunks = ParentRecipientResolver.chunkStudentIds(requested);

      for (final chunk in chunks) {
        final snap = await firestore
            .collection(FirestoreCollections.parentProfiles)
            .where('childrenIds', arrayContainsAny: chunk)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final children = List<String>.from(data['childrenIds'] ?? []);
          ParentRecipientResolver.mergeParentProfile(
            into: result,
            parentId: doc.id,
            childrenIds: children,
            requestedStudentIds: requestedSet,
          );
        }
      }

      return result;
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
  Future<PaymentPublicSettingsEntity> getPaymentPublicSettings() async {
    try {
      final doc = await firestore
          .collection(FirestoreCollections.academySettings)
          .doc(AcademyPaymentSettingsContract.paymentPublicDocId)
          .get();
      return paymentPublicSettingsFromData(doc.data());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PaymentAccessEntity?> getPaymentAccess(String parentId) async {
    try {
      final doc = await firestore
          .collection(FirestoreCollections.paymentAccess)
          .doc(parentId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data() ?? const <String, dynamic>{};
      DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
      final status =
          (data[PaymentAccessContract.statusField] as String?)?.trim() ??
          PaymentAccessContract.statusOk;
      if (!PaymentAccessContract.isValidStatus(status)) {
        throw const ServerException('حالة صلاحية الدفع غير صالحة');
      }
      final affected =
          data[PaymentAccessContract.affectedStudentIdsField] as List?;
      return PaymentAccessEntity(
        parentId: parentId,
        status: status,
        reason: data[PaymentAccessContract.reasonField] as String?,
        primaryInvoiceId:
            data[PaymentAccessContract.primaryInvoiceIdField] as String?,
        affectedStudentIds:
            affected?.map((e) => e.toString()).toList() ?? const [],
        graceEndsAt: ts(data[PaymentAccessContract.graceEndsAtField]),
        suspendedAt: ts(data[PaymentAccessContract.suspendedAtField]),
        warningIssuedAt: ts(data[PaymentAccessContract.warningIssuedAtField]),
        lastReminderAt: ts(data[PaymentAccessContract.lastReminderAtField]),
        reinstatedAt: ts(data[PaymentAccessContract.reinstatedAtField]),
        reinstatedBy: data[PaymentAccessContract.reinstatedByField] as String?,
        updatedAt: ts(data[PaymentAccessContract.updatedAtField]),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> submitAbsenceRequest(AbsenceRequestModel request) async {
    try {
      final id = request.id.trim();
      if (id.isEmpty) {
        throw const ServerException('معرّف طلب الاستئذان غير صالح');
      }

      final ref = firestore
          .collection(FirestoreCollections.absenceRequests)
          .doc(id);
      final existing = await ref.get();
      if (existing.exists) {
        final raw = existing.data()?['status'];
        final status = (raw is String ? raw : '').trim();
        if (status == 'approved' || status == 'rejected') {
          throw const ServerException(
            'لا يمكن تعديل طلب استئذان بعد اتخاذ القرار',
          );
        }
      }

      // Full set (not merge): resubmit clears reviewedBy and stays pending.
      // Never touches attendanceRecords (W7 D-W7-2 / D-W7-3).
      await ref.set({
        'studentId': request.studentId,
        'halaqaId': request.halaqaId,
        'requestedBy': request.requestedBy,
        'date': Timestamp.fromDate(request.date),
        'reason': request.reason,
        'status': 'pending',
      });
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AbsenceRequestModel>> getAbsenceRequestsForParent(
    String parentId,
  ) async {
    try {
      return await AbsenceRequestFirestoreReads.forParent(
        firestore: firestore,
        parentId: parentId,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<({String id, String name})>> getHalaqatForStudent(
    String studentId,
  ) async {
    try {
      final sid = studentId.trim();
      if (sid.isEmpty) return const [];

      final snap = await firestore
          .collection(FirestoreCollections.halaqat)
          .where('studentIds', arrayContains: sid)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        final name = (data['name'] as String?)?.trim() ?? '';
        return (id: doc.id, name: name.isEmpty ? doc.id : name);
      }).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> submitPaymentProof({
    required String parentId,
    required String paymentId,
    required String localFilePath,
  }) async {
    final pid = parentId.trim();
    final payId = paymentId.trim();
    final path = localFilePath.trim();
    if (pid.isEmpty || payId.isEmpty || path.isEmpty) {
      throw const ServerException('بيانات إثبات الدفع غير صالحة');
    }

    final file = File(path);
    if (!await file.exists()) {
      throw const ServerException('ملف الإيصال غير موجود');
    }
    final length = await file.length();
    if (length <= 0) {
      throw const ServerException('ملف الإيصال فارغ');
    }
    if (length >= ParentPaymentProofContract.maxBytes) {
      throw const ServerException('حجم الإيصال أكبر من ١٠ ميجا');
    }
    final check = await UploadFilePolicy.checkFile(
      file,
      formats: ParentPaymentProofContract.formats,
    );
    final format = check.format;
    if (format == null) {
      throw ServerException(check.error ?? 'صيغة الإيصال غير مدعومة');
    }

    try {
      final paymentRef = firestore
          .collection(FirestoreCollections.payments)
          .doc(payId);
      final paymentSnap = await paymentRef.get();
      if (!paymentSnap.exists) {
        throw const ServerException('الدفعة غير موجودة');
      }
      final pdata = paymentSnap.data() ?? const <String, dynamic>{};
      if ((pdata['parentId'] as String? ?? '').trim() != pid) {
        throw const ServerException('هذه الدفعة غير مرتبطة بحسابك');
      }
      final status = (pdata['status'] as String? ?? '').trim();
      if (status == 'paid') {
        throw const ServerException('تم سداد هذه الدفعة بالفعل');
      }

      var fileName = _unconfirmedUploads.reusableFileName(payId, path);
      if (fileName == null) {
        fileName = ParentPaymentProofContract.proofFileName(format);
        await storage
            .ref(
              ParentPaymentProofContract.storagePath(
                parentId: pid,
                paymentId: payId,
                fileName: fileName,
              ),
            )
            .putFile(file, SettableMetadata(contentType: format.contentType));
        _unconfirmedUploads.remember(payId, path, fileName);
      }

      // Only the server makes the upload the current proof (new cycle);
      // pending is shown after it confirms and the payment is re-read.
      final response = await functions
          .httpsCallable(ParentPaymentProofContract.submitCallable)
          .call(<String, dynamic>{'paymentId': payId, 'fileName': fileName});
      _unconfirmedUploads.settle(payId);
      final data = response.data;
      final cycle = data is Map ? data['proofCycleId'] : null;
      if (!ParentPaymentProofContract.isProofCycleId(
        cycle is String ? cycle : null,
      )) {
        throw const ServerException('تعذر تأكيد إرسال الإيصال، حدّث الصفحة');
      }
    } on FirebaseFunctionsException catch (e) {
      if (UnconfirmedProofUploads.definitiveCodes.contains(e.code)) {
        _unconfirmedUploads.settle(payId);
      }
      throw ServerException(e.message ?? e.code);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Uint8List> downloadPaymentProof({
    required String parentId,
    required String paymentId,
    required String storagePath,
  }) async {
    if (!ParentPaymentProofContract.isTrustedStoragePath(
      storagePath,
      parentId: parentId,
      paymentId: paymentId,
    )) {
      throw const ServerException('بيانات صورة الإيصال غير صالحة');
    }
    try {
      final bytes = await storage
          .ref(storagePath.trim())
          .getData(ParentPaymentProofContract.maxBytes);
      if (bytes == null || bytes.isEmpty) {
        throw const ServerException('صورة الإيصال غير موجودة');
      }
      return bytes;
    } on FirebaseException catch (e) {
      throw ServerException(switch (e.code) {
        'object-not-found' => 'صورة الإيصال غير موجودة',
        'unauthorized' => 'لا تملك صلاحية عرض هذا الإيصال',
        _ => 'تعذر تحميل صورة الإيصال',
      });
    }
  }

  @override
  Future<ParentHousehold> getHousehold({
    required String parentId,
    required List<String> childrenIds,
  }) async {
    try {
      final ids = childrenIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList();
      if (parentId.trim().isEmpty) {
        throw const ServerException('معرّف ولي الأمر غير صالح');
      }
      if (ids.isEmpty) return const ParentHousehold();

      final children = await Future.wait(ids.map(_loadChildSnapshot));
      final staff = _staffFromChildren(children);
      final admins = await _loadAdmins();
      final merged = <String, ParentStaffContact>{
        for (final c in staff) c.uid: c,
        for (final a in admins) a.uid: a,
      };

      return ParentHousehold(
        children: children,
        staffContacts: merged.values.toList(),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ParentAttendanceMark>> getAttendanceMarks({
    required String studentId,
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    try {
      final sid = studentId.trim();
      if (sid.isEmpty) return const [];

      final snap = await firestore
          .collection(FirestoreCollections.attendanceRecords)
          .where('studentId', isEqualTo: sid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(endExclusive))
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        final rawDate = data['date'];
        final date = rawDate is Timestamp
            ? rawDate.toDate()
            : (rawDate is DateTime ? rawDate : start);
        return ParentAttendanceMark(
          id: doc.id,
          studentId: sid,
          halaqaId: (data['halaqaId'] as String?) ?? '',
          date: date,
          status: (data['status'] as String?) ?? '',
        );
      }).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<ParentChildSnapshot> _loadChildSnapshot(String studentId) async {
    final now = DateTime.now();
    final todayStart = AttendancePolicy.dayStart(now);
    final windowStart = todayStart.subtract(
      const Duration(days: StudentAtRiskPolicy.windowDays),
    );
    final windowEnd = AttendancePolicy.dayEndExclusive(now);

    final userFuture = firestore
        .collection(FirestoreCollections.users)
        .doc(studentId)
        .get();
    final profileFuture = firestore
        .collection(FirestoreCollections.studentProfiles)
        .doc(studentId)
        .get();
    final attendanceFuture = firestore
        .collection(FirestoreCollections.attendanceRecords)
        .where('studentId', isEqualTo: studentId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart))
        .where('date', isLessThan: Timestamp.fromDate(windowEnd))
        .get();
    final recitationFuture = firestore
        .collection(FirestoreCollections.recitationRecords)
        .where('studentId', isEqualTo: studentId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart))
        .where('date', isLessThan: Timestamp.fromDate(windowEnd))
        .get();

    final results = await Future.wait([
      userFuture,
      profileFuture,
      attendanceFuture,
      recitationFuture,
    ]);
    final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final profileDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
    final attendanceSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final recitationSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

    final userData = userDoc.data();
    final profileData = profileDoc.data();
    final name =
        ((userData?['name'] as String?) ??
                (profileData?['name'] as String?) ??
                '')
            .trim();
    final imageUrl = userData?['profileImageUrl'] as String?;

    var halaqaId = (profileData?['halaqaId'] as String?)?.trim() ?? '';
    if (halaqaId.isEmpty) {
      final halaqat = await getHalaqatForStudent(studentId);
      if (halaqat.isNotEmpty) halaqaId = halaqat.first.id;
    }

    String halaqaName = (profileData?['halaqaName'] as String?)?.trim() ?? '';
    String? teacherId;
    String teacherName = '';
    String? teacherImageUrl;
    String? supervisorId;
    String supervisorName = '';
    String? supervisorImageUrl;

    if (halaqaId.isNotEmpty) {
      final halaqaDoc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .get();
      final hdata = halaqaDoc.data();
      if (hdata != null) {
        final hn = (hdata['name'] as String?)?.trim() ?? '';
        if (hn.isNotEmpty) halaqaName = hn;
        teacherId = (hdata['teacherId'] as String?)?.trim();
        supervisorId = (hdata['supervisorId'] as String?)?.trim();
      }
    }

    final staffIds = [
      if (teacherId != null && teacherId.isNotEmpty) teacherId,
      if (supervisorId != null && supervisorId.isNotEmpty) supervisorId,
    ];
    if (staffIds.isNotEmpty) {
      final staffDocs = await Future.wait(
        staffIds.map(
          (id) =>
              firestore.collection(FirestoreCollections.users).doc(id).get(),
        ),
      );
      for (final doc in staffDocs) {
        final n = (doc.data()?['name'] as String?)?.trim() ?? '';
        final image = doc.data()?['profileImageUrl'] as String?;
        if (doc.id == teacherId) {
          teacherName = n;
          teacherImageUrl = image;
        }
        if (doc.id == supervisorId) {
          supervisorName = n;
          supervisorImageUrl = image;
        }
      }
    }

    final marks = attendanceSnap.docs.map((d) {
      final data = d.data();
      final rawDate = data['date'];
      final date = rawDate is Timestamp
          ? rawDate.toDate()
          : (rawDate is DateTime ? rawDate : todayStart);
      return AttendanceMarkRef(
        id: d.id,
        halaqaId: (data['halaqaId'] as String?) ?? '',
        studentId: studentId,
        date: date,
        status: data['status'] as String?,
        sessionId: data['sessionId'] as String?,
      );
    }).toList();

    final todayMarks = marks.where(
      (m) => AttendancePolicy.isSameCalendarDay(m.date, now),
    );
    final todayStatus = _pickTodayStatus(
      AttendancePolicy.uniqueDayStatuses(todayMarks),
    );

    final windowStatuses = AttendancePolicy.uniqueDayStatuses(marks);
    final nonExcused = windowStatuses
        .where((s) => !AttendancePolicy.isExcusedStatus(s))
        .toList();
    final attendancePercent = nonExcused.isEmpty
        ? null
        : AttendancePolicy.attendancePercentFromStatuses(windowStatuses);

    var hasEval = false;
    RecitationGrade? latestGrade;
    DateTime? latestGradeDate;
    for (final doc in recitationSnap.docs) {
      final data = doc.data();
      if (!AnalyticsRecitationHonesty.countsAsEvaluationForAtRisk(
        reviewStatus: data['reviewStatus'] as String?,
        grade: data['grade'] as String?,
      )) {
        continue;
      }
      hasEval = true;
      final grade = _recitationGradeFrom(data['grade']);
      if (grade == null) continue;
      final rawDate = data['date'];
      final date = rawDate is Timestamp
          ? rawDate.toDate()
          : (rawDate is DateTime ? rawDate : now);
      if (latestGradeDate == null || date.isAfter(latestGradeDate)) {
        latestGradeDate = date;
        latestGrade = grade;
      }
    }

    final signal = StudentAtRiskPolicy.evaluate(
      marksInWindow: marks,
      hasEvaluationInWindow: hasEval,
    );

    return ParentChildSnapshot(
      studentId: studentId,
      name: name,
      profileImageUrl: imageUrl,
      halaqaId: halaqaId.isEmpty ? null : halaqaId,
      halaqaName: halaqaName,
      teacherId: teacherId,
      teacherName: teacherName,
      teacherProfileImageUrl: teacherImageUrl,
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      supervisorProfileImageUrl: supervisorImageUrl,
      overallProgressPercent:
          (profileData?['overallProgressPercent'] as num?)?.toDouble() ?? 0,
      totalVersesMemorized:
          (profileData?['totalVersesMemorized'] as num?)?.toInt() ?? 0,
      streakDays: (profileData?['streakDays'] as num?)?.toInt() ?? 0,
      todayAttendanceStatus: todayStatus,
      isAtRisk: signal != null,
      riskSignal: signal,
      attendancePercentInWindow: attendancePercent,
      latestReviewedGrade: latestGrade,
    );
  }

  List<ParentStaffContact> _staffFromChildren(
    List<ParentChildSnapshot> children,
  ) {
    final byId = <String, ParentStaffContact>{};
    for (final child in children) {
      final teacherId = child.teacherId?.trim() ?? '';
      if (teacherId.isNotEmpty) {
        byId[teacherId] = ParentStaffContact(
          uid: teacherId,
          name: child.teacherName,
          role: AppRoles.teacher,
          profileImageUrl: child.teacherProfileImageUrl,
        );
      }
      final supervisorId = child.supervisorId?.trim() ?? '';
      if (supervisorId.isNotEmpty) {
        byId[supervisorId] = ParentStaffContact(
          uid: supervisorId,
          name: child.supervisorName,
          role: AppRoles.supervisor,
          profileImageUrl: child.supervisorProfileImageUrl,
        );
      }
    }
    return byId.values.toList();
  }

  @override
  Future<List<AchievementModel>> getChildAchievements(String studentId) async {
    try {
      final response = await functions
          .httpsCallable('getParentAchievements')
          .call(<String, dynamic>{'studentId': studentId});
      return parseParentAchievementsResponse(response.data);
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(parentAchievementsErrorMessage(e.code, e.message));
    } catch (_) {
      throw const ServerException(kParentAchievementsLoadFailedMessage);
    }
  }

  Future<List<ParentStaffContact>> _loadAdmins() async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.users)
          .where('role', isEqualTo: AppRoles.admin)
          .limit(20)
          .get();
      return [
        for (final doc in snap.docs)
          ParentStaffContact(
            uid: doc.id,
            name: (doc.data()['name'] as String?)?.trim() ?? '',
            role: AppRoles.admin,
            profileImageUrl: doc.data()['profileImageUrl'] as String?,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static String? _pickTodayStatus(Iterable<String?> statuses) {
    final list = statuses
        .map((s) => (s ?? '').trim())
        .where((s) => s.isNotEmpty);
    if (list.contains(AttendancePolicy.statusPresent)) {
      return AttendancePolicy.statusPresent;
    }
    if (list.contains(AttendancePolicy.statusLate)) {
      return AttendancePolicy.statusLate;
    }
    if (list.contains(AttendancePolicy.statusExcused)) {
      return AttendancePolicy.statusExcused;
    }
    if (list.contains(AttendancePolicy.statusAbsent)) {
      return AttendancePolicy.statusAbsent;
    }
    return null;
  }

  static RecitationGrade? _recitationGradeFrom(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return switch (raw) {
      'ممتاز' => RecitationGrade.excellent,
      'جيد جداً' => RecitationGrade.veryGood,
      'جيد' => RecitationGrade.good,
      'يحتاج تحسين' => RecitationGrade.needsRetry,
      _ => null,
    };
  }
}
