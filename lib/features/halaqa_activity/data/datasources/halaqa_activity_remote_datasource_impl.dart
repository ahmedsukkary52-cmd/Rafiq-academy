import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/domain/assignment_kind.dart';
import '../../../../shared/domain/assignment_policy.dart';
import '../../domain/entities/halaqa_activity_entity.dart';
import 'halaqa_activity_remote_datasource.dart';

@LazySingleton(as: HalaqaActivityRemoteDatasource)
class HalaqaActivityRemoteDatasourceImpl
    implements HalaqaActivityRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  static const _uploadTimeout = Duration(seconds: 25);

  HalaqaActivityRemoteDatasourceImpl({
    required this.firestore,
    required this.storage,
  });

  CollectionReference<Map<String, dynamic>> get _assignments =>
      firestore.collection(FirestoreCollections.assignments);

  @override
  Future<({String activityId, List<AcademyEvent> events})> publishActivity({
    required String halaqaId,
    required String teacherId,
    required String teacherName,
    required String prompt,
    required Set<HalaqaActivityResponseType> allowedResponseTypes,
    DateTime? deadline,
    bool alsoShareAsPost = false,
  }) async {
    try {
      final halaqaDoc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .get();
      if (!halaqaDoc.exists) {
        throw const ServerException('الحلقة غير موجودة');
      }
      final data = halaqaDoc.data() ?? {};
      final studentIds = List<String>.from(data['studentIds'] ?? []);
      if (studentIds.isEmpty) {
        throw const ServerException(
          'لا يوجد طلاب في هذه الحلقة لنشر المهمة',
        );
      }
      if (studentIds.length > 500) {
        throw const ServerException(
          'عدد طلاب الحلقة كبير جداً لنشر المهمة دفعة واحدة.',
        );
      }

      final now = DateTime.now();
      final ref = _assignments.doc();
      final allowed = allowedResponseTypes
          .map((t) => t.wireValue)
          .toList(growable: false);

      await ref.set({
        AssignmentPolicy.kindField: AssignmentKind.wireHalaqaActivity,
        AssignmentPolicy.halaqaIdField: halaqaId,
        'assignedBy': teacherId,
        'teacherName': teacherName,
        // Not a per-student lesson homework doc.
        AssignmentPolicy.studentIdField: '',
        'prompt': prompt,
        'title': prompt,
        'allowedResponseTypes': allowed,
        AssignmentPolicy.createdAtField: Timestamp.fromDate(now),
        // Keep dueDate for index compatibility; optional deadline or createdAt.
        AssignmentPolicy.dueDateField: Timestamp.fromDate(deadline ?? now),
        if (deadline != null) 'deadline': Timestamp.fromDate(deadline),
        'alsoShareAsPost': alsoShareAsPost,
        'responseCount': 0,
        'respondentStudentIds': <String>[],
        'newMemorizationRange': '',
        'reviewRange': '',
        'isSubmitted': false,
        'tasks': <Map<String, dynamic>>[],
        'attachments': <Map<String, dynamic>>[],
      });

      final events = studentIds
          .map(
            (studentId) => HalaqaActivityPublished(
              activityId: ref.id,
              studentId: studentId,
              halaqaId: halaqaId,
              assignedBy: teacherId,
              prompt: prompt,
              deadline: deadline,
            ),
          )
          .toList(growable: false);

      return (activityId: ref.id, events: events);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> attachMirroredPostId({
    required String activityId,
    required String postId,
  }) async {
    try {
      await _assignments.doc(activityId).set({
        'postId': postId,
        'alsoShareAsPost': true,
      }, SetOptions(merge: true));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<HalaqaActivityEntity>> listActivitiesForHalaqa(
    String halaqaId,
  ) async {
    try {
      final snap = await _assignments
          .where(AssignmentPolicy.halaqaIdField, isEqualTo: halaqaId)
          .where(
            AssignmentPolicy.kindField,
            isEqualTo: AssignmentKind.wireHalaqaActivity,
          )
          .orderBy(AssignmentPolicy.createdAtField, descending: true)
          .limit(50)
          .get();

      return snap.docs.map(_activityFromDoc).toList(growable: false);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<HalaqaActivityEntity> getActivity({
    required String halaqaId,
    required String activityId,
    bool includeThread = true,
  }) async {
    try {
      final doc = await _assignments.doc(activityId).get();
      if (!doc.exists) {
        throw const ServerException('تعذر العثور على هذه المهمة');
      }
      final data = doc.data();
      if (data == null ||
          !AssignmentPolicy.isHalaqaActivityData(data) ||
          (data[AssignmentPolicy.halaqaIdField] as String? ?? '') !=
              halaqaId) {
        throw const ServerException('هذه المهمة خارج نطاق الحلقة');
      }

      var activity = _activityFromDoc(doc);
      if (includeThread) {
        final thread = await _loadThread(activityId);
        final respondents = thread
            .map((e) => e.studentId)
            .where((id) => id.isNotEmpty)
            .toSet();
        activity = activity.copyWith(
          thread: thread,
          responseCount: respondents.length,
          respondentStudentIds: respondents,
        );
      }
      return activity;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<HalaqaActivityResponseEntity> submitResponse({
    required String activityId,
    required String halaqaId,
    required String studentId,
    required String studentName,
    String? text,
    File? imageFile,
    File? audioFile,
  }) async {
    try {
      final activity = await getActivity(
        halaqaId: halaqaId,
        activityId: activityId,
        includeThread: false,
      );

      final halaqaDoc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .get();
      final roster = List<String>.from(
        (halaqaDoc.data() ?? const {})['studentIds'] ?? const [],
      );
      if (!roster.contains(studentId)) {
        throw const ServerException(
          'غير مسموح بالرد على مهمة خارج حلقتك',
        );
      }

      if (text != null &&
          text.trim().isNotEmpty &&
          !activity.allowedResponseTypes.contains(
            HalaqaActivityResponseType.text,
          )) {
        throw const ServerException('هذه المهمة لا تقبل رداً نصياً');
      }
      if (imageFile != null &&
          !activity.allowedResponseTypes.contains(
            HalaqaActivityResponseType.image,
          )) {
        throw const ServerException('هذه المهمة لا تقبل صورة');
      }
      if (audioFile != null &&
          !activity.allowedResponseTypes.contains(
            HalaqaActivityResponseType.audio,
          )) {
        throw const ServerException('هذه المهمة لا تقبل صوتاً');
      }
      if (audioFile != null && !AppCapabilities.audioUploadsEnabled) {
        throw const ServerException(
          'رفع الصوت غير مفعّل حالياً (AppCapabilities.audioUploadsEnabled)',
        );
      }

      String? imageUrl;
      String? imageLabel;
      String? audioUrl;
      String? audioLabel;

      if (imageFile != null) {
        final uploaded = await _uploadMedia(
          activityId: activityId,
          studentId: studentId,
          file: imageFile,
          folder: 'images',
          contentType: 'image/jpeg',
        );
        imageUrl = uploaded.url;
        imageLabel = uploaded.name;
      }
      if (audioFile != null) {
        final uploaded = await _uploadMedia(
          activityId: activityId,
          studentId: studentId,
          file: audioFile,
          folder: 'audio',
          contentType: 'audio/mp4',
        );
        audioUrl = uploaded.url;
        audioLabel = uploaded.name;
      }

      final responseRef = _assignments
          .doc(activityId)
          .collection(FirestoreCollections.activityResponsesSubcollection)
          .doc();
      final now = DateTime.now();
      final payload = <String, dynamic>{
        'studentId': studentId,
        'studentName': studentName,
        'createdAt': Timestamp.fromDate(now),
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (imageLabel != null) 'imageLabel': imageLabel,
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (audioLabel != null) 'audioLabel': audioLabel,
      };
      await responseRef.set(payload);

      // Best-effort unique student count refresh for list cards.
      final thread = await _loadThread(activityId);
      final respondents = thread
          .map((e) => e.studentId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      await _assignments.doc(activityId).set({
        'responseCount': respondents.length,
        'respondentStudentIds': respondents,
      }, SetOptions(merge: true));

      return HalaqaActivityResponseEntity(
        id: responseRef.id,
        activityId: activityId,
        studentId: studentId,
        studentName: studentName,
        createdAt: now,
        text: text?.trim().isEmpty ?? true ? null : text!.trim(),
        imageUrl: imageUrl,
        audioUrl: audioUrl,
        imageLabel: imageLabel,
        audioLabel: audioLabel,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<HalaqaActivityResponseEntity>> _loadThread(
    String activityId,
  ) async {
    final snap = await _assignments
        .doc(activityId)
        .collection(FirestoreCollections.activityResponsesSubcollection)
        .orderBy('createdAt')
        .limit(200)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return HalaqaActivityResponseEntity(
        id: doc.id,
        activityId: activityId,
        studentId: data['studentId'] as String? ?? '',
        studentName: data['studentName'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        text: data['text'] as String?,
        imageUrl: data['imageUrl'] as String?,
        audioUrl: data['audioUrl'] as String?,
        imageLabel: data['imageLabel'] as String?,
        audioLabel: data['audioLabel'] as String?,
      );
    }).toList(growable: false);
  }

  HalaqaActivityEntity _activityFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final allowedRaw = data['allowedResponseTypes'];
    final allowed = <HalaqaActivityResponseType>{};
    if (allowedRaw is List) {
      for (final item in allowedRaw) {
        final parsed = HalaqaActivityResponseTypeWire.tryParse(item);
        if (parsed != null) allowed.add(parsed);
      }
    }
    if (allowed.isEmpty) {
      allowed.add(HalaqaActivityResponseType.text);
    }

    final prompt =
        (data['prompt'] as String?)?.trim().isNotEmpty == true
        ? (data['prompt'] as String).trim()
        : ((data['title'] as String?)?.trim() ?? '');

    return HalaqaActivityEntity(
      id: doc.id,
      halaqaId: data[AssignmentPolicy.halaqaIdField] as String? ?? '',
      teacherId: data['assignedBy'] as String? ?? '',
      teacherName: (data['teacherName'] as String?)?.trim().isNotEmpty == true
          ? (data['teacherName'] as String).trim()
          : 'المعلم',
      prompt: prompt,
      createdAt:
          (data[AssignmentPolicy.createdAtField] as Timestamp?)?.toDate() ??
          (data[AssignmentPolicy.dueDateField] as Timestamp?)?.toDate() ??
          DateTime.now(),
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      allowedResponseTypes: allowed,
      alsoShareAsPost: data['alsoShareAsPost'] as bool? ?? false,
      postId: data['postId'] as String?,
      responseCount: (data['responseCount'] as num?)?.toInt() ?? 0,
      respondentStudentIds: {
        for (final id in List<String>.from(
          data['respondentStudentIds'] ?? const <String>[],
        ))
          if (id.trim().isNotEmpty) id.trim(),
      },
    );
  }

  Future<({String url, String name})> _uploadMedia({
    required String activityId,
    required String studentId,
    required File file,
    required String folder,
    required String contentType,
  }) async {
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'attachment';
    final path =
        'halaqa_activities/$activityId/$studentId/$folder/'
        '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = storage.ref(path);
    final task = await ref
        .putFile(file, SettableMetadata(contentType: contentType))
        .timeout(_uploadTimeout);
    final url = await task.ref.getDownloadURL();
    return (url: url, name: fileName);
  }
}
