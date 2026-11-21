import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-only access path to private email (`userPrivate/{uid}.email`).
///
/// firestore.rules lets only an active Admin or the owner `get` these
/// documents (never `list`, never client writes), and refuses any document
/// still carrying a legacy contact field. Only `email` is taken from the
/// document. This is the single app file allowed to name the collection.
class AdminPrivateEmailReader {
  static const String collection = 'userPrivate';

  final FirebaseFirestore firestore;

  const AdminPrivateEmailReader(this.firestore);

  /// The private email, or null when the document is missing, unreadable
  /// (e.g. awaiting the legacy phone cleanup) or holds no usable email.
  Future<String?> emailOf(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return null;
    try {
      final snap = await firestore.collection(collection).doc(id).get();
      return _clean(snap.data()?['email']);
    } on FirebaseException {
      return null;
    }
  }

  /// Parallel private-email reads for a registration / directory page.
  ///
  /// `userPrivate` is get-only (no `list` / `whereIn`), so each uid is still
  /// one document get — batched with [Future.wait] to cut wall-clock latency.
  Future<Map<String, String?>> emailsOf(
    Iterable<String> uids, {
    int parallel = 12,
  }) async {
    final ids = <String>[];
    final seen = <String>{};
    for (final raw in uids) {
      final id = raw.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      ids.add(id);
    }
    final out = <String, String?>{};
    for (var i = 0; i < ids.length; i += parallel) {
      final slice = ids.sublist(
        i,
        i + parallel > ids.length ? ids.length : i + parallel,
      );
      final pairs = await Future.wait(
        slice.map((id) async => MapEntry(id, await emailOf(id))),
      );
      for (final e in pairs) {
        out[e.key] = e.value;
      }
    }
    return out;
  }

  /// Transition order: private email first, then the legacy `users.email`
  /// until the separately approved migration removes it.
  static String? preferPrivate(
    String? privateEmail,
    Object? legacyUsersEmail,
  ) => _clean(privateEmail) ?? _clean(legacyUsersEmail);

  static String? _clean(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }
}
