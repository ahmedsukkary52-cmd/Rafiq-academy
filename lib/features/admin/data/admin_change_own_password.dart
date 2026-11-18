import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/error/exception.dart';

/// Arabic messages for the signed-in admin "change own password" flow.
///
/// Kept separate from login [AuthErrorMessages] because this path intentionally
/// reveals wrong-current-password (the user already proved ownership of the
/// session) and uses settings-specific recovery copy.
String adminChangeOwnPasswordMessage(String code) => switch (code) {
  'wrong-password' ||
  'invalid-credential' ||
  'invalid-login-credentials' => 'كلمة المرور الحالية غير صحيحة',
  'too-many-requests' => 'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة',
  'weak-password' => 'كلمة المرور الجديدة ضعيفة',
  'network-request-failed' => 'تعذر الاتصال. تحقق من الإنترنت',
  'requires-recent-login' || 'user-mismatch' || 'user-not-found' =>
    'سجّل الدخول من جديد ثم أعد المحاولة',
  _ => 'تعذر تغيير كلمة المرور، حاول مرة أخرى',
};

/// Re-authenticates with [currentPassword], then sets [newPassword].
///
/// Pass the DI-resolved [FirebaseAuth] (emulator-aware), never
/// `FirebaseAuth.instance`, so local flavors hit the correct app.
Future<void> changeOwnPasswordWithAuth({
  required FirebaseAuth auth,
  required String currentPassword,
  required String newPassword,
}) async {
  final user = auth.currentUser;
  final email = user?.email;
  if (user == null || email == null || email.isEmpty) {
    throw const ServerException('سجّل الدخول من جديد ثم أعد المحاولة');
  }
  try {
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    await user.updatePassword(newPassword);
  } on FirebaseAuthException catch (e) {
    throw ServerException(adminChangeOwnPasswordMessage(e.code));
  }
}
