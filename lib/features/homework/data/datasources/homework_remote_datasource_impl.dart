import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../student/data/models/assignment_model.dart';
import '../../../student/data/models/recitation_record_model.dart';
import '../../../student/domain/entities/assignment_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../domain/entities/homework_entity.dart';
import 'homework_remote_datasource.dart';

/// Single Source of Truth: collection [FirestoreCollections.assignments]
/// + تسميعات الطالب في [FirestoreCollections.recitationRecords]
@LazySingleton(as: HomeworkRemoteDatasource)
class HomeworkRemoteDatasourceImpl implements HomeworkRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  static const _uploadTimeout = Duration(seconds: 20);

  HomeworkRemoteDatasourceImpl(this.firestore, this.storage);

  Query<Map<String, dynamic>> _latestQuery(String studentId) {
    return firestore
        .collection(FirestoreCollections.assignments)
        .where('studentId', isEqualTo: studentId)
        .orderBy('dueDate', descending: true)
        .limit(1);
  }

  @override
  Future<HomeworkEntity?> getLatestHomework(String studentId) async {
    try {
      final snapshot = await _latestQuery(studentId).get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      await _ensureHomeworkFields(doc);
      final refreshed = await doc.reference.get();
      return _toHomework(AssignmentModel.fromFirestore(refreshed));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<HomeworkEntity?> watchLatestHomework(String studentId) {
    return _latestQuery(studentId).snapshots().asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      await _ensureHomeworkFields(doc);
      final refreshed = await doc.reference.get();
      return _toHomework(AssignmentModel.fromFirestore(refreshed));
    });
  }

  /// لو المستند قديم بدون tasks/attachments — نزرع الحقول على نفس الـ document في Firestore.
  Future<void> _ensureHomeworkFields(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;
    final tasks = data['tasks'];
    if (tasks is List && tasks.isNotEmpty) return;

    final seed = AssignmentModel.defaultHomeworkFields(
      newMemorizationRange: data['newMemorizationRange'] as String? ?? '',
      reviewRange: data['reviewRange'] as String? ?? '',
    );
    await doc.reference.set(seed, SetOptions(merge: true));
  }

  HomeworkEntity _toHomework(AssignmentModel a) {
    return HomeworkEntity(
      id: a.id,
      title: a.displayTitle.isNotEmpty ? a.displayTitle : 'واجب اليوم',
      dueAt: a.dueDate,
      studentId: a.studentId,
      assignedBy: a.assignedBy,
      halaqaId: a.halaqaId,
      newMemorizationRange: a.newMemorizationRange,
      reviewRange: a.reviewRange,
      isSubmitted: a.isSubmitted,
      completedAt: a.completedAt,
      tasks: a.tasks
          .map(
            (t) => HomeworkTaskEntity(
              id: t.id,
              title: t.title,
              points: t.points,
              isCompleted: t.isCompleted,
              kind: _parseKind(t.kind),
              recitationRecordId: t.recitationRecordId,
            ),
          )
          .toList(),
      teacherVoiceNote: a.teacherVoiceNote == null
          ? null
          : TeacherVoiceNoteEntity(
              teacherName: a.teacherVoiceNote!.teacherName,
              audioUrl: a.teacherVoiceNote!.audioUrl,
              duration: Duration(seconds: a.teacherVoiceNote!.durationSeconds),
            ),
      attachments: a.attachments
          .map(
            (att) => HomeworkAttachmentEntity(
              id: att.id,
              name: att.name,
              url: att.url,
              sizeLabel: att.sizeLabel,
            ),
          )
          .toList(),
    );
  }

  HomeworkTaskKind _parseKind(String kind) {
    return switch (kind) {
      'reading' => HomeworkTaskKind.reading,
      'listening' => HomeworkTaskKind.listening,
      'review' => HomeworkTaskKind.review,
      'recitation' => HomeworkTaskKind.recitation,
      'quiz' => HomeworkTaskKind.quiz,
      _ => HomeworkTaskKind.other,
    };
  }

  @override
  Future<HomeworkEntity> toggleTask({
    required String homeworkId,
    required String taskId,
  }) async {
    try {
      final ref = firestore
          .collection(FirestoreCollections.assignments)
          .doc(homeworkId);
      final doc = await ref.get();
      if (!doc.exists) {
        throw const ServerException('التكليف غير موجود');
      }
      final assignment = AssignmentModel.fromFirestore(doc);
      if (assignment.isSubmitted) {
        throw const ServerException(
          'تم إنهاء هذا الواجب — لا يمكن تعديل المهام',
        );
      }
      final updatedTasks = assignment.tasks.map((t) {
        if (t.id != taskId) return t;
        return AssignmentTaskEntity(
          id: t.id,
          title: t.title,
          points: t.points,
          isCompleted: !t.isCompleted,
          kind: t.kind,
          recitationRecordId: t.recitationRecordId,
        );
      }).toList();

      await ref.update({'tasks': updatedTasks.map((t) => t.toMap()).toList()});

      final refreshed = await ref.get();
      return _toHomework(AssignmentModel.fromFirestore(refreshed));
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<int> completeHomework(String homeworkId) async {
    try {
      final assignmentRef = firestore
          .collection(FirestoreCollections.assignments)
          .doc(homeworkId);

      // Transaction يضمن: فحص isSubmitted + كتابة التسليم + إضافة النقاط مرة واحدة فقط
      final awardedPoints = await firestore.runTransaction<int>((txn) async {
        final snap = await txn.get(assignmentRef);
        if (!snap.exists) {
          throw const ServerException('التكليف غير موجود');
        }

        final data = snap.data()!;
        final alreadySubmitted =
            data['isSubmitted'] == true || data['status'] == 'completed';
        if (alreadySubmitted) {
          throw const ServerException('تم إنهاء هذا الواجب مسبقاً');
        }

        final homework = _toHomework(AssignmentModel.fromFirestore(snap));
        if (!homework.allCompleted) {
          throw const ServerException('لم تكتمل كل المهام بعد');
        }

        final points = homework.earnedPoints;

        txn.update(assignmentRef, {
          'isSubmitted': true,
          'completedAt': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        if (homework.studentId.isNotEmpty && points > 0) {
          final profileRef = firestore
              .collection(FirestoreCollections.studentProfiles)
              .doc(homework.studentId);
          txn.set(profileRef, {
            'points': FieldValue.increment(points),
            'coins': FieldValue.increment(points),
          }, SetOptions(merge: true));
        }

        return points;
      });

      return awardedPoints;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<HomeworkEntity> submitRecitation(SubmitRecitationParams params) async {
    try {
      final file = File(params.localFilePath);
      if (!file.existsSync()) {
        throw const ServerException('ملف التسجيل غير موجود');
      }

      final assignmentRef = firestore
          .collection(FirestoreCollections.assignments)
          .doc(params.assignmentId);
      final assignmentSnap = await assignmentRef.get();
      if (!assignmentSnap.exists) {
        throw const ServerException('التكليف غير موجود');
      }
      final assignment = AssignmentModel.fromFirestore(assignmentSnap);
      if (assignment.isSubmitted) {
        throw const ServerException(
          'تم إنهاء هذا الواجب — لا يمكن إرسال تسميع',
        );
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath =
          'recitations/${params.studentId}/${params.assignmentId}/'
          '${params.taskId}_$timestamp.m4a';
      final storageRef = storage.ref(storagePath);

      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(contentType: 'audio/mp4'),
      );

      try {
        await uploadTask.timeout(_uploadTimeout);
      } on TimeoutException {
        await uploadTask.cancel();
        throw const ServerException(
          'انتهت مهلة رفع التسجيل — تحقق من الاتصال وحاول مرة أخرى',
        );
      }

      final audioUrl = await storageRef.getDownloadURL().timeout(
        _uploadTimeout,
        onTimeout: () => throw const ServerException(
          'فشل الحصول على رابط التسجيل — حاول مرة أخرى',
        ),
      );

      final recordRef = firestore
          .collection(FirestoreCollections.recitationRecords)
          .doc();
      final now = DateTime.now();

      final record = RecitationRecordModel(
        id: recordRef.id,
        studentId: params.studentId,
        studentName: params.studentName,
        teacherId: params.teacherId,
        halaqaId: params.halaqaId,
        date: now,
        type: RecitationType.memorization,
        versesRange: params.versesRange,
        // الدرجات تُكتب فقط بعد مراجعة المعلم — مش قيم وهمية
        grade: null,
        behaviorGrade: null,
        notes: 'تسميع مرسل من الطالب — بانتظار المراجعة',
        audioUrl: audioUrl,
        storagePath: storagePath,
        assignmentId: params.assignmentId,
        taskId: params.taskId,
        submittedAt: now,
        reviewStatus: 'pending',
        durationSeconds: params.durationSeconds,
      );

      // كتابة السجل + تعليم المهمة في batch واحد (atomic نسبياً)
      await firestore.runTransaction((txn) async {
        final fresh = await txn.get(assignmentRef);
        if (!fresh.exists) {
          throw const ServerException('التكليف غير موجود');
        }
        final current = AssignmentModel.fromFirestore(fresh);
        if (current.isSubmitted) {
          throw const ServerException('تم إنهاء هذا الواجب');
        }

        final updatedTasks = current.tasks.map((t) {
          if (t.id != params.taskId) return t;
          // لو المهمة مكتملة مسبقاً بنفس التسميع — نستبدل الـ record فقط (بدون نقاط إضافية)
          return AssignmentTaskEntity(
            id: t.id,
            title: t.title,
            points: t.points,
            isCompleted: true,
            kind: t.kind,
            recitationRecordId: recordRef.id,
          );
        }).toList();

        if (!updatedTasks.any((t) => t.id == params.taskId)) {
          throw const ServerException('مهمة التسميع غير موجودة في الواجب');
        }

        txn.set(recordRef, record.toFirestore());
        txn.update(assignmentRef, {
          'tasks': updatedTasks.map((t) => t.toMap()).toList(),
        });
      });

      final refreshed = await assignmentRef.get();
      return _toHomework(AssignmentModel.fromFirestore(refreshed));
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
