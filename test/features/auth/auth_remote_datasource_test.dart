import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/auth/data/datasources/auth_remote_datasouce_impl.dart';
import 'package:rafiq_academy/features/auth/domain/auth_error_messages.dart';

import 'auth_fakes.dart';

Map<String, dynamic> profile(String role, {bool? isActive}) => {
  'name': 'User',
  'role': role,
  if (isActive != null) 'isActive': isActive,
};

void main() {
  late FakeFirebaseAuth auth;
  late FakeFirestore firestore;
  late AuthRemoteDatasourceImpl ds;

  setUp(() {
    auth = FakeFirebaseAuth(
      emailToUid: {
        'student@x.test': 'stu1',
        'ghost@x.test': 'ghost',
        'off@x.test': 'off1',
        'odd@x.test': 'odd1',
        'legacy@x.test': 'legacy1',
      },
      passwords: {
        'stu1': 'secret1',
        'ghost': 'secret1',
        'off1': 'secret1',
        'odd1': 'secret1',
        'legacy1': 'secret1',
      },
    );
    firestore = FakeFirestore({
      'users/stu1': profile('student', isActive: true),
      'users/off1': profile('teacher', isActive: false),
      'users/odd1': profile('superadmin', isActive: true),
      'users/legacy1': profile('parent'),
    });
    ds = AuthRemoteDatasourceImpl(firebaseAuth: auth, firestore: firestore);
  });

  Future<AuthException> loginError(
    String email, [
    String pass = 'secret1',
  ]) async {
    try {
      await ds.loginWithEmail(email: email, password: pass);
    } on AuthException catch (e) {
      return e;
    }
    fail('expected AuthException');
  }

  group('login', () {
    test(
      'success returns the server-written role and keeps the session',
      () async {
        final user = await ds.loginWithEmail(
          email: 'student@x.test',
          password: 'secret1',
        );
        expect(user.uid, 'stu1');
        expect(user.role, 'student');
        expect(auth.currentUser?.uid, 'stu1');
      },
    );

    test('legacy profile without isActive is treated as active', () async {
      final user = await ds.loginWithEmail(
        email: 'legacy@x.test',
        password: 'secret1',
      );
      expect(user.role, 'parent');
    });

    test(
      'wrong password and unknown email share one message (no enumeration)',
      () async {
        final wrong = await loginError('student@x.test', 'bad-pass');
        final unknown = await loginError('nobody@x.test');
        expect(wrong.reason, AuthErrorReason.invalidCredentials);
        expect(unknown.reason, AuthErrorReason.invalidCredentials);
        expect(wrong.message, unknown.message);
        expect(wrong.message, AuthErrorMessages.invalidCredentials);
      },
    );

    test(
      'Firebase identity without an academy profile is rejected and signed out',
      () async {
        final e = await loginError('ghost@x.test');
        expect(e.reason, AuthErrorReason.notProvisioned);
        expect(auth.currentUser, isNull);
        expect(auth.signOutCalls, 1);
      },
    );

    test('deactivated profile is rejected and signed out', () async {
      final e = await loginError('off@x.test');
      expect(e.reason, AuthErrorReason.disabled);
      expect(e.message, AuthErrorMessages.disabled);
      expect(auth.currentUser, isNull);
    });

    test('unknown role fails closed (never reaches a role home)', () async {
      final e = await loginError('odd@x.test');
      expect(e.reason, AuthErrorReason.notProvisioned);
      expect(auth.currentUser, isNull);
    });

    test('Firebase-disabled account maps to the disabled state', () async {
      auth.signInErrorCode = 'user-disabled';
      final e = await loginError('student@x.test');
      expect(e.reason, AuthErrorReason.disabled);
    });

    test('network failure is retryable', () async {
      auth.signInErrorCode = 'network-request-failed';
      final e = await loginError('student@x.test');
      expect(e.reason, AuthErrorReason.network);
    });

    test(
      'profile read outage signs out and reports a network problem',
      () async {
        firestore.getErrorCode = 'unavailable';
        final e = await loginError('student@x.test');
        expect(e.reason, AuthErrorReason.network);
        expect(auth.currentUser, isNull);
      },
    );
  });

  group('session restore', () {
    test('no session -> null', () async {
      expect(await ds.getCurrentUser(), isNull);
    });

    test(
      'waits for Firebase to restore a persisted session (cold start)',
      () async {
        auth
          ..restoreFromStream = true
          ..restoredUser = FakeUser('stu1');
        final user = await ds.getCurrentUser();
        expect(user?.uid, 'stu1');
      },
    );

    test('restored session whose profile is now disabled is ended', () async {
      auth = FakeFirebaseAuth(current: FakeUser('off1'));
      ds = AuthRemoteDatasourceImpl(firebaseAuth: auth, firestore: firestore);
      await expectLater(
        ds.getCurrentUser(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthErrorReason.disabled,
          ),
        ),
      );
      expect(auth.signOutCalls, 1);
    });

    test('restored session with a missing profile is ended', () async {
      auth = FakeFirebaseAuth(current: FakeUser('ghost'));
      ds = AuthRemoteDatasourceImpl(firebaseAuth: auth, firestore: firestore);
      await expectLater(ds.getCurrentUser(), throwsA(isA<AuthException>()));
      expect(auth.signOutCalls, 1);
    });

    test('offline restore keeps the session for a retry', () async {
      auth = FakeFirebaseAuth(current: FakeUser('stu1'));
      ds = AuthRemoteDatasourceImpl(firebaseAuth: auth, firestore: firestore);
      firestore.getErrorCode = 'unavailable';
      await expectLater(
        ds.getCurrentUser(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthErrorReason.network,
          ),
        ),
      );
      expect(auth.signOutCalls, 0);
      expect(auth.currentUser?.uid, 'stu1');
    });

    test('session uid stream reports sign-out as null', () async {
      await ds.loginWithEmail(email: 'student@x.test', password: 'secret1');
      final next = ds.sessionUidChanges.skip(1).first;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await ds.logout();
      expect(await next, isNull);
    });
  });

  group('own email comes from Firebase Auth', () {
    test('profile without users.email still shows the Auth email', () async {
      final user = await ds.loginWithEmail(
        email: 'student@x.test',
        password: 'secret1',
      );
      expect(user.email, 'student@x.test');
    });

    test('Auth email wins over a legacy users.email', () async {
      firestore.docs['users/stu1'] = {
        ...profile('student', isActive: true),
        'email': 'stale@x.test',
      };
      final user = await ds.loginWithEmail(
        email: 'student@x.test',
        password: 'secret1',
      );
      expect(user.email, 'student@x.test');
    });

    test('transition: legacy users.email is kept when Auth has none', () async {
      firestore.docs['users/stu1'] = {
        ...profile('student', isActive: true),
        'email': 'legacy-only@x.test',
      };
      auth = FakeFirebaseAuth(current: FakeUser('stu1'));
      ds = AuthRemoteDatasourceImpl(firebaseAuth: auth, firestore: firestore);
      final user = await ds.getCurrentUser();
      expect(user?.email, 'legacy-only@x.test');
    });

    test('restored session uses the Auth email', () async {
      auth = FakeFirebaseAuth(
        current: FakeUser('stu1', email: 'restored@x.test'),
      );
      ds = AuthRemoteDatasourceImpl(firebaseAuth: auth, firestore: firestore);
      final user = await ds.getCurrentUser();
      expect(user?.email, 'restored@x.test');
    });
  });

  group('password reset', () {
    test('sends the Firebase reset email in Arabic', () async {
      await ds.sendPasswordResetEmail(email: 'student@x.test');
      expect(auth.resetEmails, ['student@x.test']);
      expect(auth.languageCode, 'ar');
    });

    test('unknown address looks like success (no enumeration)', () async {
      auth.resetErrorCode = 'user-not-found';
      await ds.sendPasswordResetEmail(email: 'nobody@x.test');
    });

    test('invalid address and network failure are reported', () async {
      auth.resetErrorCode = 'invalid-email';
      await expectLater(
        ds.sendPasswordResetEmail(email: 'bad'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthErrorReason.invalidEmail,
          ),
        ),
      );
      auth.resetErrorCode = 'network-request-failed';
      await expectLater(
        ds.sendPasswordResetEmail(email: 'student@x.test'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthErrorReason.network,
          ),
        ),
      );
    });
  });
}
