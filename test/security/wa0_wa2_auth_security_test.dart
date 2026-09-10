import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/provision_user_usecase.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/domain/repositories/auth_repository.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/register_with_email_usecase.dart';
import 'package:rafiq_academy/features/parent/domain/parent_wallet.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    return const Left(
      AuthFailure(
        'التسجيل العام غير متاح. يتم إنشاء الحسابات بواسطة الإدارة فقط',
      ),
    );
  }

  @override
  Stream<UserEntity?> get authStateChanges => const Stream.empty();

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> loginWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> logout() => throw UnimplementedError();
}

class _FakeAdminRepository implements AdminRepository {
  bool provisionCalled = false;
  String? lastRole;

  @override
  Future<Either<Failure, String>> provisionUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
    bool isActive = true,
  }) async {
    provisionCalled = true;
    lastRole = role;
    if (role == AppRoles.admin && email == 'denied@test.com') {
      return const Left(ServerFailure('هذه العملية متاحة للمسؤول فقط'));
    }
    return const Right('uid-new');
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('WA-1 public registration closed (D1/C1)', () {
    test('RegisterWithEmailUseCase returns auth failure', () async {
      final useCase = RegisterWithEmailUseCase(_FakeAuthRepository());
      final result = await useCase(
        const RegisterParams(
          email: 'a@b.com',
          password: 'secret1',
          name: 'Test',
          phone: '010',
          role: AppRoles.student,
        ),
      );
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f.message, contains('التسجيل العام غير متاح')),
        (_) => fail('expected failure'),
      );
    });

    test('AppRoutes.register deep-link is not an allowed auth shell', () {
      expect(
        AppRouteAccess.isAllowed(
          path: AppRoutes.register,
          role: AppRoles.student,
        ),
        isFalse,
      );
    });
  });

  group('WA-1 Admin provision use case', () {
    test('forwards to repository and returns uid', () async {
      final repo = _FakeAdminRepository();
      final useCase = ProvisionUserUseCase(repo);
      final result = await useCase(
        const ProvisionUserParams(
          email: 'student@test.com',
          password: 'secret1',
          name: 'طالب',
          role: AppRoles.student,
        ),
      );
      expect(repo.provisionCalled, isTrue);
      expect(result, const Right('uid-new'));
    });
  });

  group('WA-2 D2 wallet quarantine', () {
    test('ParentWalletContract.enabled is false', () {
      expect(ParentWalletContract.enabled, isFalse);
    });
  });

  group('WA-2 AuthException contract for disabled register datasource', () {
    test('message matches product copy', () {
      const e = AuthException(
        'التسجيل العام غير متاح. يتم إنشاء الحسابات بواسطة الإدارة فقط',
      );
      expect(e.message, contains('الإدارة فقط'));
    });
  });
}
