import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/entities/mushaf_position.dart';
import 'mushaf_reading_local_mirror.dart';

abstract class MushafReadingRemoteDatasource {
  /// C15 `mushafReading/{studentId}`. Null when the document is missing or
  /// its fields are unusable.
  Future<MushafPosition?> getLastRead(String studentId);

  Future<void> saveLastRead({
    required String studentId,
    required MushafPosition position,
  });
}

@LazySingleton(as: MushafReadingRemoteDatasource)
class MushafReadingRemoteDatasourceImpl
    implements MushafReadingRemoteDatasource {
  final FirebaseFirestore firestore;
  final MushafReadingLocalMirror mirror;

  MushafReadingRemoteDatasourceImpl(this.firestore, this.mirror);

  DocumentReference<Map<String, dynamic>> _doc(String studentId) =>
      firestore.collection(FirestoreCollections.mushafReading).doc(studentId);

  @override
  Future<MushafPosition?> getLastRead(String studentId) async {
    final Map<String, dynamic>? data;
    try {
      final snap = await _doc(studentId).get();
      data = snap.exists ? snap.data() : null;
    } catch (e) {
      final mirrored = await mirror.read(studentId);
      if (mirrored != null) return mirrored;
      if (e is FirebaseException) {
        throw ServerException(e.message ?? 'تعذر قراءة موضع المصحف');
      }
      throw ServerException('تعذر قراءة موضع المصحف: $e');
    }
    return positionFromDoc(data);
  }

  /// Validates raw C15 fields; anything malformed yields null.
  static MushafPosition? positionFromDoc(Map<String, dynamic>? data) {
    if (data == null) return null;
    final page = data['pageNumber'];
    final surah = data['surahNumber'];
    final ayah = data['ayahNumber'];
    if (page is! num || surah is! num || ayah is! num) return null;
    if (ayah.toInt() < 1) return null;
    final position = MushafPosition(
      pageNumber: page.toInt(),
      surahNumber: surah.toInt(),
      ayahNumber: ayah.toInt(),
    );
    return position.isValid ? position : null;
  }

  @override
  Future<void> saveLastRead({
    required String studentId,
    required MushafPosition position,
  }) async {
    await mirror.write(studentId, position);

    try {
      await _doc(studentId).set({
        'surahNumber': position.surahNumber,
        'ayahNumber': position.ayahNumber,
        'pageNumber': position.pageNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort: Firestore queues offline writes; denied writes are
      // non-fatal for reading.
    }
  }
}
