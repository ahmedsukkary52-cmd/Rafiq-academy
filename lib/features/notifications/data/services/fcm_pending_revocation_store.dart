import 'package:shared_preferences/shared_preferences.dart';

/// Durable record of accounts whose push revocation on this install was never
/// confirmed (H2).
///
/// Entries are Firebase uids only — never the FCM token. An entry means
/// "`fcmTokens/{uid}/devices/{thisDevice}` may still be enabled", and it
/// survives process restarts so recovery can run before another account
/// registers this device.
abstract class FcmPendingRevocationStore {
  Future<Set<String>> read();

  Future<void> write(Set<String> uids);
}

/// Not registered in DI: the generated config is frozen (OA-56), so this is
/// the dependency-free default of `FcmTokenRegistrar.pendingRevocations`.
class SharedPreferencesFcmPendingRevocationStore
    implements FcmPendingRevocationStore {
  static const String prefsKey = 'h2.fcm.pending_revocation_uids';

  const SharedPreferencesFcmPendingRevocationStore();

  @override
  Future<Set<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final uid in prefs.getStringList(prefsKey) ?? const <String>[])
        if (uid.trim().isNotEmpty) uid.trim(),
    };
  }

  @override
  Future<void> write(Set<String> uids) async {
    final prefs = await SharedPreferences.getInstance();
    if (uids.isEmpty) {
      await prefs.remove(prefsKey);
    } else {
      await prefs.setStringList(prefsKey, uids.toList()..sort());
    }
  }
}
