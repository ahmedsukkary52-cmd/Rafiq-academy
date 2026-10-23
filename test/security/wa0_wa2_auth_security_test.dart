import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart';
import 'package:rafiq_academy/features/admin/domain/usecases/provision_user_usecase.dart';

Iterable<File> _libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

class _FakeAdminRepository implements AdminRepository {
  bool provisionCalled = false;
  String? lastRole;

  @override
  Future<Either<Failure, String>> provisionUser({
    required String email,
    required String password,
    required String name,
    required String role,
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
    test('the self-registration page, event and use case are removed', () {
      for (final path in [
        'lib/features/auth/presentation/pages/register_page.dart',
        'lib/features/auth/domain/usecases/register_with_email_usecase.dart',
      ]) {
        expect(File(path).existsSync(), isFalse, reason: path);
      }
      for (final path in [
        'lib/features/auth/domain/repositories/auth_repository.dart',
        'lib/features/auth/data/datasources/auth_remote_datasource.dart',
        'lib/features/auth/presentation/bloc/auth_event.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('register')),
          reason: path,
        );
      }
    });

    test('no client code creates Firebase Auth identities', () {
      for (final file in _libDartFiles()) {
        expect(
          file.readAsStringSync(),
          isNot(contains('createUserWithEmailAndPassword')),
          reason: file.path,
        );
      }
    });

    test('no client code writes users/{uid}.role on create', () {
      // users create is `false` in the rules; the client must not try either.
      for (final file in _libDartFiles()) {
        final src = file.readAsStringSync();
        expect(
          RegExp(r"collection\(\s*FirestoreCollections\.users\s*\)[\s\S]{0,80}\.set\(").hasMatch(src),
          isFalse,
          reason: file.path,
        );
      }
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

    test('server denial is returned, not swallowed', () async {
      final repo = _FakeAdminRepository();
      final result = await ProvisionUserUseCase(repo)(
        const ProvisionUserParams(
          email: 'denied@test.com',
          password: 'secret1',
          name: 'مسؤول',
          role: AppRoles.admin,
        ),
      );
      expect(repo.lastRole, AppRoles.admin);
      expect(
        result,
        const Left<Failure, String>(ServerFailure('هذه العملية متاحة للمسؤول فقط')),
      );
    });
  });
}
