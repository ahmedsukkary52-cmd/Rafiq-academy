import '../../../core/error/exception.dart';

/// Arabic Auth copy + Firebase error-code mapping (one place, RTL-safe).
abstract final class AuthErrorMessages {
  static const generic = 'حدث خطأ غير متوقع، حاول مرة أخرى';
  static const invalidCredentials =
      'البريد الإلكتروني أو كلمة المرور غير صحيحة';
  static const invalidEmail = 'البريد الإلكتروني غير صالح';
  static const notProvisioned =
      'هذا الحساب غير مفعّل في الأكاديمية. يرجى التواصل مع الإدارة';
  static const disabled = 'هذا الحساب موقوف، يرجى التواصل مع الإدارة';
  static const network = 'تعذّر الاتصال، تحقق من الشبكة وحاول مرة أخرى';
  static const tooManyRequests = 'تم تجاوز عدد المحاولات، حاول لاحقاً';
  static const sessionEnded = 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
  static const logoutFailed = 'تعذّر تسجيل الخروج، حاول مرة أخرى';
  static const permissionDenied = 'ليس لديك صلاحية الوصول إلى هذا الحساب';

  /// User-not-found and wrong-password share one message so the login form
  /// never reveals which addresses are registered.
  static AuthException fromAuthCode(String code) => switch (code) {
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' ||
    'invalid-login-credentials' => const AuthException(
      invalidCredentials,
      reason: AuthErrorReason.invalidCredentials,
    ),
    'invalid-email' || 'missing-email' => const AuthException(
      invalidEmail,
      reason: AuthErrorReason.invalidEmail,
    ),
    'user-disabled' => const AuthException(
      disabled,
      reason: AuthErrorReason.disabled,
    ),
    'too-many-requests' => const AuthException(
      tooManyRequests,
      reason: AuthErrorReason.tooManyRequests,
    ),
    'network-request-failed' => const AuthException(
      network,
      reason: AuthErrorReason.network,
    ),
    'user-token-expired' || 'requires-recent-login' => const AuthException(
      sessionEnded,
      reason: AuthErrorReason.sessionEnded,
    ),
    _ => const AuthException(generic),
  };

  static AuthException fromFirestoreCode(String code) => switch (code) {
    'unavailable' || 'deadline-exceeded' => const AuthException(
      network,
      reason: AuthErrorReason.network,
    ),
    'permission-denied' => const AuthException(
      permissionDenied,
      reason: AuthErrorReason.notProvisioned,
    ),
    _ => const AuthException(generic),
  };
}
