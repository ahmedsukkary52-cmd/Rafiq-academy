import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../domain/client_version_config.dart';

enum ClientVersionReadSource { server, cache }

/// Raw access to `appConfig/clientVersion`; throws on read failure.
abstract class ClientVersionSource {
  /// Document data, or null when the document does not exist.
  Future<Map<String, dynamic>?> read(ClientVersionReadSource source);
}

@LazySingleton(as: ClientVersionSource)
class FirestoreClientVersionSource implements ClientVersionSource {
  final FirebaseFirestore firestore;

  FirestoreClientVersionSource(this.firestore);

  @override
  Future<Map<String, dynamic>?> read(ClientVersionReadSource source) async {
    final snapshot = await firestore
        .collection(clientVersionCollection)
        .doc(clientVersionDocId)
        .get(
          GetOptions(
            source: source == ClientVersionReadSource.server
                ? Source.server
                : Source.cache,
          ),
        );
    return snapshot.exists ? snapshot.data() : null;
  }
}
