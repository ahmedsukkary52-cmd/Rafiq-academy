import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../academy_login_identifier.dart';
import '../repositories/auth_repository.dart';

/// Shown instead of sending: academy usernames map to an undeliverable
/// `.invalid` address, so only an Admin-issued temporary password recovers them.
const kUsernameRecoveryMessage =
    'هذا الحساب يدخل باسم مستخدم من الأكاديمية ولا يستقبل رسائل بريد. '
    'اطلب من إدارة الأكاديمية إصدار كلمة مرور مؤقتة جديدة.';

/// Firebase email-link reset: the user sets the new password through the
/// Firebase action page, then signs in again.
@lazySingleton
class SendPasswordResetUseCase extends UseCase<Unit, String> {
  final AuthRepository repository;

  SendPasswordResetUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String email) async {
    final value = email.trim();
    if (AcademyLoginIdentifier.isInternalEmail(value) ||
        AcademyLoginIdentifier.isUsername(value)) {
      return const Left(ValidationFailure(kUsernameRecoveryMessage));
    }
    return repository.sendPasswordResetEmail(email: value);
  }
}
