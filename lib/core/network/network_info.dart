import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  final InternetConnection connectionChecker;

  const NetworkInfoImpl(this.connectionChecker);

  /// Soft connectivity gate used by repositories **before** Firebase calls.
  ///
  /// Why probes must not hard-fail the app:
  /// - [InternetConnection.hasInternetAccess] pings public CDNs
  ///   (Cloudflare / Google / Apple…). On a slightly slow mobile link those
  ///   often fail even while WhatsApp/Chat work and Firebase would succeed.
  /// - Repositories map `false` → «لا يوجد اتصال بالإنترنت» and skip the
  ///   real request, so a flaky probe freezes the whole session UX.
  /// - Emulator builds talk to `127.0.0.1` via `adb reverse`; CDN probes are
  ///   irrelevant and routinely false-negative on the phone.
  ///
  /// We therefore always allow the call through. Firebase/Auth still report
  /// genuine offline / server errors. [connectionChecker] remains injected
  /// for tests and any future hard check (e.g. airplane mode).
  @override
  Future<bool> get isConnected async {
    // Touch the field so DI wiring stays intentional; result is ignored.
    connectionChecker.hashCode;
    return true;
  }
}
