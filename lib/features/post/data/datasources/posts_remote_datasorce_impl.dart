import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/post/data/datasources/posts_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/entities/posts_entities.dart';
import '../models/post_models.dart';

@LazySingleton(as: PostsRemoteDatasource)
class PostsRemoteDatasourceImpl implements PostsRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  const PostsRemoteDatasourceImpl({
    required this.firestore,
    required this.storage,
  });

  CollectionReference get _postsRef =>
      firestore.collection(FirestoreCollections.posts);

  @override
  Stream<List<PostModel>> watchPosts({required String halaqaId}) {
    // نجيب منشورات الحلقة المحددة + المنشورات العامة لكل الحلقات.
    // Firestore مش بتدعم OR query على حقلين مختلفين في query واحد،
    // بنستخدم whereIn على حقل واحد (audience_target) بدل ما نعمل
    // mergين لقائمتين مختلفتين - أبسط وأقل reads.
    return _postsRef
        .where('audienceTarget', whereIn: [halaqaId, 'all'])
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(PostModel.fromFirestore).toList());
  }

  @override
  Stream<List<CommentModel>> watchComments(String postId) {
    return _postsRef
        .doc(postId)
        .collection(FirestoreCollections.commentsSubcollection)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => CommentModel.fromFirestore(doc, postId: postId))
              .toList(),
        );
  }

  @override
  Future<void> createPost({
    required String authorId,
    required String authorName,
    required String content,
    required String? halaqaId,
    required PostAudience audience,
    List<File> attachmentFiles = const [],
    List<AttachmentType> attachmentTypes = const [],
  }) async {
    try {
      // أولاً: رفع المرفقات على Storage لو وجدت
      final attachments = <PostAttachmentModel>[];

      for (int i = 0; i < attachmentFiles.length; i++) {
        final file = attachmentFiles[i];
        final type = attachmentTypes[i];
        final fileName = file.path.split('/').last;
        final ext = _extensionForType(type);

        final storagePath =
            'posts/$authorId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

        final ref = storage.ref(storagePath);
        final task = await ref.putFile(file);
        final url = await task.ref.getDownloadURL();

        final fileSizeMb = file.lengthSync() / (1024 * 1024);

        attachments.add(
          PostAttachmentModel(
            url: url,
            type: type,
            fileName: fileName,
            fileSizeMb: double.parse(fileSizeMb.toStringAsFixed(1)),
          ),
        );
      }

      // ثانياً: حفظ الـ document في Firestore
      // audienceTarget = halaqaId للمنشورات الخاصة بحلقة، أو 'all' للعامة.
      // بنستخدم حقل واحد عشان الـ whereIn query في watchPosts يشتغل.
      final audienceTarget = audience == PostAudience.allHalaqat
          ? 'all'
          : halaqaId ?? 'all';

      await _postsRef.add({
        'authorId': authorId,
        'authorName': authorName,
        'content': content,
        'halaqaId': halaqaId,
        'audience': audience == PostAudience.allHalaqat
            ? 'allHalaqat'
            : 'specificHalaqa',
        'audienceTarget': audienceTarget,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'isPinned': false,
        'likedBy': <String>[],
        'commentsCount': 0,
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> toggleLike({
    required String postId,
    required String uid,
    required bool isCurrentlyLiked,
  }) async {
    try {
      await _postsRef.doc(postId).update({
        'likedBy': isCurrentlyLiked
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String content,
  }) async {
    try {
      final batch = firestore.batch();

      // إضافة التعليق في الـ subcollection
      final commentRef = _postsRef
          .doc(postId)
          .collection(FirestoreCollections.commentsSubcollection)
          .doc();

      batch.set(commentRef, {
        'authorId': authorId,
        'authorName': authorName,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // تحديث عداد التعليقات في الـ post نفسه (denormalized)
      batch.update(_postsRef.doc(postId), {
        'commentsCount': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> togglePin({
    required String postId,
    required bool isPinned,
  }) async {
    try {
      await _postsRef.doc(postId).update({'isPinned': isPinned});
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      // حذف التعليقات أولاً (Firestore مش بيحذف الـ subcollections تلقائياً)
      final commentsSnap = await _postsRef
          .doc(postId)
          .collection(FirestoreCollections.commentsSubcollection)
          .get();

      final batch = firestore.batch();
      for (final doc in commentsSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_postsRef.doc(postId));
      await batch.commit();

      // ملاحظة: الملفات على Storage مش بتتحذف هنا عشان محتاجين
      // الـ URLs المخزّنة في الـ document اللي اتحذف. الحل الصح هو
      // Cloud Function تستمع لحذف documents وتحذف الملفات المرتبطة.
      // ده نضيفه لاحقاً في مرحلة الـ production.
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  String _extensionForType(AttachmentType type) => switch (type) {
    AttachmentType.pdf => 'pdf',
    AttachmentType.audio => 'm4a',
    AttachmentType.image => 'jpg',
    AttachmentType.video => 'mp4',
  };
}
