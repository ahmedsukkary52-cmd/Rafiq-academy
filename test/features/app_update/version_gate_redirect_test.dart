import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/features/app_update/presentation/bloc/client_version_gate_bloc.dart';
import 'package:rafiq_academy/features/app_update/presentation/version_gate_redirect.dart';

void main() {
  var delegated = 0;

  String? resolve(ClientVersionGateStatus status, String path) =>
      VersionGateRedirect.resolve(
        status: status,
        path: path,
        splashPath: AppRoutes.splash,
        updatePath: AppRoutes.updateRequired,
        otherwise: () {
          delegated++;
          return '/delegated';
        },
      );

  setUp(() => delegated = 0);

  const guarded = [
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.forgotPassword,
    AppRoutes.student,
    AppRoutes.admin,
  ];

  test('checking holds every route on splash without delegating', () {
    expect(resolve(ClientVersionGateStatus.checking, AppRoutes.splash), isNull);
    expect(
      resolve(ClientVersionGateStatus.checking, AppRoutes.updateRequired),
      AppRoutes.splash,
    );
    for (final path in guarded) {
      expect(resolve(ClientVersionGateStatus.checking, path), AppRoutes.splash);
    }
    expect(delegated, 0);
  });

  test('update required blocks onboarding, auth and role routes', () {
    expect(
      resolve(ClientVersionGateStatus.updateRequired, AppRoutes.updateRequired),
      isNull,
    );
    for (final path in [AppRoutes.splash, ...guarded]) {
      expect(
        resolve(ClientVersionGateStatus.updateRequired, path),
        AppRoutes.updateRequired,
      );
    }
    expect(delegated, 0);
  });

  test('allowed leaves the update screen and delegates everything else', () {
    expect(
      resolve(ClientVersionGateStatus.allowed, AppRoutes.updateRequired),
      AppRoutes.splash,
    );
    expect(delegated, 0);
    expect(
      resolve(ClientVersionGateStatus.allowed, AppRoutes.login),
      '/delegated',
    );
    expect(delegated, 1);
  });
}
