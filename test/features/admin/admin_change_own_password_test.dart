import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/admin/data/admin_change_own_password.dart';

class _PasswordUser extends Fake implements User {
  _PasswordUser({required this.email, this.reauthError, this.updateError});

  @override
  final String? email;

  final String? reauthError;
  final String? updateError;
  final reauthPasswords = <String>[];
  final updatedPasswords = <String>[];

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential? credential,
  ) async {
    final password = (credential as EmailAuthCredential?)?.password ?? '';
    reauthPasswords.add(password);
    final code = reauthError;
    if (code != null) throw FirebaseAuthException(code: code);
    return _Credential(this);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatedPasswords.add(newPassword);
    final code = updateError;
    if (code != null) throw FirebaseAuthException(code: code);
  }
}

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);

  @override
  final User? user;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUser);

  @override
  final User? currentUser;
}

bool _codeUsesFirebaseInstance(String source) {
  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
    if (trimmed.contains('FirebaseAuth.instance')) return true;
    if (trimmed.contains('FirebaseFirestore.instance')) return true;
  }
  return false;
}

void main() {
  group('adminChangeOwnPasswordMessage', () {
    test('maps known Auth codes to settings copy', () {
      expect(
        adminChangeOwnPasswordMessage('wrong-password'),
        'كلمة المرور الحالية غير صحيحة',
      );
      expect(
        adminChangeOwnPasswordMessage('invalid-credential'),
        'كلمة المرور الحالية غير صحيحة',
      );
      expect(
        adminChangeOwnPasswordMessage('too-many-requests'),
        'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة',
      );
      expect(
        adminChangeOwnPasswordMessage('weak-password'),
        'كلمة المرور الجديدة ضعيفة',
      );
      expect(
        adminChangeOwnPasswordMessage('network-request-failed'),
        'تعذر الاتصال. تحقق من الإنترنت',
      );
      expect(
        adminChangeOwnPasswordMessage('requires-recent-login'),
        'سجّل الدخول من جديد ثم أعد المحاولة',
      );
      expect(
        adminChangeOwnPasswordMessage('mystery-code'),
        'تعذر تغيير كلمة المرور، حاول مرة أخرى',
      );
    });
  });

  group('changeOwnPasswordWithAuth', () {
    test('fails closed when there is no signed-in email user', () async {
      await expectLater(
        () => changeOwnPasswordWithAuth(
          auth: _Auth(null),
          currentPassword: 'old',
          newPassword: 'newpass99',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'سجّل الدخول من جديد ثم أعد المحاولة',
          ),
        ),
      );

      await expectLater(
        () => changeOwnPasswordWithAuth(
          auth: _Auth(_PasswordUser(email: '')),
          currentPassword: 'old',
          newPassword: 'newpass99',
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('reauthenticates then updates the password', () async {
      final user = _PasswordUser(email: 'admin@example.com');
      await changeOwnPasswordWithAuth(
        auth: _Auth(user),
        currentPassword: 'old-secret',
        newPassword: 'new-secret-2026',
      );
      expect(user.reauthPasswords, ['old-secret']);
      expect(user.updatedPasswords, ['new-secret-2026']);
    });

    test('maps wrong current password without calling updatePassword', () async {
      final user = _PasswordUser(
        email: 'admin@example.com',
        reauthError: 'wrong-password',
      );
      await expectLater(
        () => changeOwnPasswordWithAuth(
          auth: _Auth(user),
          currentPassword: 'bad',
          newPassword: 'new-secret-2026',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'كلمة المرور الحالية غير صحيحة',
          ),
        ),
      );
      expect(user.updatedPasswords, isEmpty);
    });

    test('maps weak-password from updatePassword', () async {
      final user = _PasswordUser(
        email: 'admin@example.com',
        updateError: 'weak-password',
      );
      await expectLater(
        () => changeOwnPasswordWithAuth(
          auth: _Auth(user),
          currentPassword: 'old-secret',
          newPassword: '123',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'كلمة المرور الجديدة ضعيفة',
          ),
        ),
      );
      expect(user.reauthPasswords, ['old-secret']);
    });
  });

  test('password change lives in data with DI Auth, not FirebaseAuth.instance', () {
    final data = File(
      'lib/features/admin/data/admin_change_own_password.dart',
    ).readAsStringSync();
    expect(data, contains('changeOwnPasswordWithAuth'));
    expect(data, contains('required FirebaseAuth auth'));
    expect(_codeUsesFirebaseInstance(data), isFalse);

    final page = File(
      'lib/features/admin/presentation/pages/admin_settings_tab.dart',
    ).readAsStringSync();
    expect(page, contains('changeOwnPasswordWithAuth'));
    expect(page, contains('sl<FirebaseAuth>()'));
    expect(_codeUsesFirebaseInstance(page), isFalse);
  });
}
