import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../shared/domain/student_search_contract.dart';
import '../models/student_search_entry_model.dart';

abstract class StudentSearchRemoteDatasource {
  /// Teacher / Supervisor scope — the only shape Rules accept for staff.
  Future<List<StudentSearchEntryModel>> searchInViewerScope({
    required String viewerUid,
    required String query,
    int limit,
  });

  /// Admin global directory (prefix-only by contract).
  Future<List<StudentSearchEntryModel>> searchAll({
    required String query,
    int limit,
  });

  /// Admin halaqa-scoped — also the landing point of a halaqa-name lookup.
  Future<List<StudentSearchEntryModel>> searchInHalaqa({
    required String halaqaId,
    required String query,
    int limit,
  });

  Future<StudentSearchEntryModel?> getByStudentId(String studentId);
}

/// C13 / WA-14 — the four frozen query shapes, and nothing else.
///
/// Every staff query carries `visibleTo array-contains <viewer>`: Rules
/// evaluate per returned document, so an unscoped or spoofed-scope query is
/// rejected rather than silently over-returning.
@LazySingleton(as: StudentSearchRemoteDatasource)
class StudentSearchRemoteDatasourceImpl
    implements StudentSearchRemoteDatasource {
  final FirebaseFirestore firestore;

  const StudentSearchRemoteDatasourceImpl({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(StudentSearchContract.collection);

  /// Normalized prefix range on the frozen query key.
  Query<Map<String, dynamic>> _withPrefix(
    Query<Map<String, dynamic>> query,
    String rawQuery,
  ) {
    final ordered = query.orderBy(
      StudentSearchContract.fullNameNormalizedField,
    );
    final prefix = StudentSearchContract.prefixStart(rawQuery);
    if (prefix.isEmpty) return ordered;
    return ordered.startAt([prefix]).endAt([
      StudentSearchContract.prefixEnd(rawQuery),
    ]);
  }

  Future<List<StudentSearchEntryModel>> _run(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      final snapshot = await query.get();
      return snapshot.docs
          .map(StudentSearchEntryModel.fromFirestore)
          .toList(growable: false);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<StudentSearchEntryModel>> searchInViewerScope({
    required String viewerUid,
    required String query,
    int limit = StudentSearchContract.defaultSearchLimit,
  }) {
    final uid = viewerUid.trim();
    if (uid.isEmpty) {
      throw const ServerException('viewerUid is required for scoped search');
    }
    return _run(
      _withPrefix(
        _collection.where(
          StudentSearchContract.visibleToField,
          arrayContains: uid,
        ),
        query,
      ).limit(limit),
    );
  }

  @override
  Future<List<StudentSearchEntryModel>> searchAll({
    required String query,
    int limit = StudentSearchContract.defaultSearchLimit,
  }) {
    return _run(_withPrefix(_collection, query).limit(limit));
  }

  @override
  Future<List<StudentSearchEntryModel>> searchInHalaqa({
    required String halaqaId,
    required String query,
    int limit = StudentSearchContract.defaultSearchLimit,
  }) {
    final id = halaqaId.trim();
    if (id.isEmpty) {
      throw const ServerException('halaqaId is required for halaqa search');
    }
    return _run(
      _withPrefix(
        _collection.where(
          StudentSearchContract.halaqaIdsField,
          arrayContains: id,
        ),
        query,
      ).limit(limit),
    );
  }

  @override
  Future<StudentSearchEntryModel?> getByStudentId(String studentId) async {
    final id = studentId.trim();
    if (id.isEmpty) return null;
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return StudentSearchEntryModel.fromFirestore(doc);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
