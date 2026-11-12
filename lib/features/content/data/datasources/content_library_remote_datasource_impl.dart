import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/content_upload_policy.dart';
import '../../domain/entities/content_file_entity.dart';
import '../datasources/content_library_remote_datasource.dart';
import '../models/content_file_model.dart';

/// Halaqa shared content (P0 §8). Every item belongs to exactly one Halaqa;
/// there is no academy-wide library.
@LazySingleton(as: ContentLibraryRemoteDatasource)
class ContentLibraryRemoteDatasourceImpl
    implements ContentLibraryRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  const ContentLibraryRemoteDatasourceImpl({
    required this.firestore,
    required this.storage,
  });

  CollectionReference get _filesRef =>
      firestore.collection(FirestoreCollections.contentLibrary);

  String _requireHalaqa(String? halaqaId) {
    final id = halaqaId?.trim() ?? '';
    if (id.isEmpty) {
      throw const ServerException('المحتوى المشترك متاح داخل الحلقة فقط');
    }
    return id;
  }

  @override
  Future<List<ContentFileModel>> getFiles({
    String? halaqaId,
    ContentFileType? filterType,
  }) async {
    final scoped = _requireHalaqa(halaqaId);
    try {
      Query query = _filesRef.where('halaqaId', isEqualTo: scoped);
      if (filterType != null) {
        query = query.where(
          'type',
          isEqualTo: ContentFileModel.typeToString(filterType),
        );
      }
      final snap = await query.get();
      return snap.docs.map(ContentFileModel.fromFirestore).toList()
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<double> uploadFile({
    required File file,
    required String title,
    required ContentFileType type,
    required String uploadedBy,
    required String uploaderName,
    String? halaqaId,
  }) async* {
    final scoped = _requireHalaqa(halaqaId);
    final fileName = file.path.split(RegExp(r'[\\/]')).last;
    final contentType = ContentUploadPolicy.contentTypeFor(fileName);
    if (contentType == null) {
      throw const ServerException(
        'نوع الملف غير مدعوم — المسموح: PDF وصوت وصور ومستندات',
      );
    }
    if (file.lengthSync() > ContentUploadPolicy.maxBytes) {
      throw const ServerException('حجم الملف أكبر من الحد المسموح (50 ميجا)');
    }
    final bytes = file.lengthSync();
    final storagePath = ContentUploadPolicy.storagePath(
      halaqaId: scoped,
      uploadedBy: uploadedBy,
      fileName: fileName,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    final ref = storage.ref(storagePath);
    yield 0.0;
    try {
      final task = ref.putFile(file, SettableMetadata(contentType: contentType));
      await for (final snapshot in task.snapshotEvents) {
        if (snapshot.state != TaskState.running) continue;
        final total = snapshot.totalBytes > 0 ? snapshot.totalBytes : bytes;
        if (total > 0) {
          yield (snapshot.bytesTransferred / total).clamp(0.0, 0.99);
        }
      }
      // Throws on error/cancel; a stream that merely ends is not success.
      final done = await task;
      if (done.state != TaskState.success) {
        throw const ServerException(ContentUploadErrors.canceled);
      }
    } on FirebaseException catch (e) {
      throw ServerException(ContentUploadErrors.forCode(e.code));
    }

    try {
      final stored = await ref.getMetadata();
      if ((stored.size ?? -1) != bytes) {
        throw const ServerException(ContentUploadErrors.incomplete);
      }
      final url = await ref.getDownloadURL();
      await _filesRef.add(
        ContentFileModel(
          id: '',
          title: title.trim().isEmpty ? fileName : title.trim(),
          type: type,
          downloadUrl: url,
          storagePath: storagePath,
          fileSizeMb: double.parse((bytes / (1024 * 1024)).toStringAsFixed(1)),
          uploadedBy: uploadedBy,
          uploaderName: uploaderName,
          uploadedAt: DateTime.now(),
          halaqaId: scoped,
        ).toFirestore(),
      );
    } catch (e) {
      // Without its library record the object is unreachable: remove it.
      await ref.delete().catchError((_) {});
      if (e is ServerException) rethrow;
      throw ServerException(
        e is FirebaseException
            ? ContentUploadErrors.forCode(e.code)
            : ContentUploadErrors.generic,
      );
    }
    yield 1.0;
  }

  @override
  Future<void> deleteFile(ContentFileEntity file) async {
    try {
      // حذف من Storage أولاً ثم من Firestore
      await storage.ref(file.storagePath).delete().catchError((Object e) {
        if (e is FirebaseException && e.code == 'object-not-found') return;
        throw e;
      });
      await _filesRef.doc(file.id).delete();
    } on FirebaseException catch (e) {
      throw ServerException(
        e.code == 'unauthorized' || e.code == 'permission-denied'
            ? 'لا تملك صلاحية حذف هذا الملف'
            : 'تعذر حذف الملف، حاول مرة أخرى',
      );
    } catch (_) {
      throw const ServerException('تعذر حذف الملف، حاول مرة أخرى');
    }
  }
}
