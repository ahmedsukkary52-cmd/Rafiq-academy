import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/entities/content_file_entity.dart';
import '../datasources/content_library_remote_datasource.dart';
import '../models/content_file_model.dart';

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

  @override
  Future<List<ContentFileModel>> getFiles({
    String? halaqaId,
    ContentFileType? filterType,
  }) async {
    try {
      Query query = _filesRef.orderBy('uploadedAt', descending: true);

      if (filterType != null) {
        query = query.where(
          'type',
          isEqualTo: ContentFileModel.typeToString(filterType),
        );
      }

      if (halaqaId != null) {
        // جلب ملفات الحلقة + الملفات العامة (halaqaId == null)
        // بنستخدم نفس حل التقويم: قراءتان ونجمعهم
        final halaqaSnap = await query
            .where('halaqaId', isEqualTo: halaqaId)
            .get();
        final generalSnap = await query.where('halaqaId', isNull: true).get();

        final all = {...halaqaSnap.docs, ...generalSnap.docs};

        return all.map(ContentFileModel.fromFirestore).toList()
          ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      }

      final snap = await query.get();
      return snap.docs.map(ContentFileModel.fromFirestore).toList();
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
    try {
      final ext = file.path.split('.').last;
      final storagePath =
          'content/$uploadedBy/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = storage.ref(storagePath);
      final task = ref.putFile(file);

      // نبعت نسبة التقدم للـ Bloc أول بأول
      await for (final snapshot in task.snapshotEvents) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        yield progress;

        if (snapshot.state == TaskState.success) {
          final url = await ref.getDownloadURL();
          final fileSizeMb = file.lengthSync() / (1024 * 1024);

          await _filesRef.add(
            ContentFileModel(
              id: '',
              title: title,
              type: type,
              downloadUrl: url,
              storagePath: storagePath,
              fileSizeMb: double.parse(fileSizeMb.toStringAsFixed(1)),
              uploadedBy: uploadedBy,
              uploaderName: uploaderName,
              uploadedAt: DateTime.now(),
              halaqaId: halaqaId,
            ).toFirestore(),
          );
        }
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteFile(ContentFileEntity file) async {
    try {
      // حذف من Storage أولاً ثم من Firestore
      await storage.ref(file.storagePath).delete();
      await _filesRef.doc(file.id).delete();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
