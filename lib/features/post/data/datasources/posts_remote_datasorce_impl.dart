import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/post/data/datasources/posts_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/domain/upload_file_policy.dart';
import '../../domain/entities/posts_entities.dart';
import '../../domain/post_attachment_policy.dart';
import '../../domain/post_audience_target.dart';
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
    // منشورات الحلقة فقط (P0 §7) — لا يوجد موجز عام لكل الأكاديمية.
    return _postsRef
        .where('audienceTarget', isEqualTo: halaqaId)
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => _dropUntrustedUrls(PostModel.fromFirestore(doc)))
              .toList(),
        );
  }

  /// Keeps a legacy `url` only when it is this project's download URL for
  /// the author's legacy folder; arbitrary links are never surfaced.
  PostModel _dropUntrustedUrls(PostModel post) {
    var changed = false;
    final next = post.attachments.map((a) {
      final model = a as PostAttachmentModel;
      if (model.url.isEmpty) return model;
      final keep =
          model.storagePath.isEmpty &&
          PostAttachmentPolicy.isLegacyDownloadUrl(
            model.url,
            bucket: storage.bucket,
            authorId: post.authorId,
          );
      if (keep) return model;
      changed = true;
      return model.withoutLegacyUrl();
    }).toList();
    return changed ? post.withAttachments(next) : post;
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
    // audienceTarget = halaqaId دائماً (المنشورات خاصة بالحلقة فقط).
    final audienceTarget = resolvePostAudienceTarget(
      audience: audience,
      halaqaId: halaqaId,
    );
    if (audienceTarget == null) {
      throw const ServerException('يجب تحديد الحلقة قبل نشر منشور خاص بها');
    }
    if (attachmentFiles.length > PostAttachmentPolicy.maxAttachments) {
      throw const ServerException(
        'الحد الأقصى ${PostAttachmentPolicy.maxAttachments} مرفقات للمنشور',
      );
    }

    // Every file is validated before the first upload starts.
    final checked = <({File file, UploadFormat format, String name})>[];
    for (final file in attachmentFiles) {
      final name = file.path.split(RegExp(r'[\\/]')).last;
      final result = await UploadFilePolicy.checkFile(
        file,
        formats: PostAttachmentPolicy.formats,
      );
      if (!result.isOk) throw ServerException('$name: ${result.error}');
      checked.add((file: file, format: result.format!, name: name));
    }

    // The post id is fixed first: Storage Rules only expose
    // posts/{halaqaId}/{postId}/… through the live posts/{postId} doc.
    final postRef = _postsRef.doc();
    final uploaded = <Reference>[];
    try {
      final attachments = <PostAttachmentModel>[];
      for (var i = 0; i < checked.length; i++) {
        final item = checked[i];
        final path = PostAttachmentPolicy.storagePath(
          halaqaId: audienceTarget,
          postId: postRef.id,
          index: i,
          format: item.format,
        );
        final ref = storage.ref(path);
        uploaded.add(ref);
        await ref.putFile(
          item.file,
          SettableMetadata(
            contentType: item.format.contentType,
            customMetadata: {'uploaderId': authorId},
          ),
        );
        final sizeMb = await item.file.length() / UploadFilePolicy.mb;
        attachments.add(
          PostAttachmentModel(
            storagePath: path,
            contentType: item.format.contentType,
            type: PostAttachmentPolicy.typeFor(item.format),
            fileName: item.name,
            fileSizeMb: double.parse(sizeMb.toStringAsFixed(1)),
          ),
        );
      }

      await postRef.set({
        'authorId': authorId,
        'authorName': authorName,
        'content': content,
        'halaqaId': audienceTarget,
        'audience': 'specificHalaqa',
        'audienceTarget': audienceTarget,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'isPinned': false,
        'likedBy': <String>[],
        'commentsCount': 0,
      });
    } catch (e) {
      await _discardUploads(uploaded);
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Best effort: Storage Rules let the uploader delete objects only while
  /// no posts/{postId} doc exists, so a post that did commit keeps its files.
  Future<void> _discardUploads(List<Reference> refs) async {
    for (final ref in refs) {
      try {
        await ref.delete();
      } on Object {
        // Left for the server-side orphan sweep (see media cleanup notes).
      }
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

  @override
  Future<void> downloadAttachment({
    required PostEntity post,
    required PostAttachmentEntity attachment,
    required File target,
  }) async {
    final path = attachment.storagePath;
    if (!PostAttachmentPolicy.isTrustedStoragePath(
      path,
      halaqaId: post.halaqaId ?? '',
      postId: post.id,
    )) {
      throw const ServerException('المرفق غير متاح');
    }
    try {
      await storage.ref(path).writeToFile(target);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.code == 'unauthorized'
            ? 'لا تملك صلاحية فتح هذا المرفق'
            : 'تعذر تحميل المرفق',
      );
    }
  }
}
