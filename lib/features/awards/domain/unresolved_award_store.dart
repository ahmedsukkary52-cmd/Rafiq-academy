/// Durable storage for award requests whose server outcome is not yet
/// confirmed, one serialized record per [key].
///
/// Records hold only the operation id and the request payload — never
/// tokens or credentials.
abstract class UnresolvedAwardStore {
  Future<String?> read(String key);

  /// Throws unless [record] was durably saved; after a throw, [read] still
  /// returns the previous value.
  Future<void> write(String key, String record);

  Future<void> remove(String key);
}
