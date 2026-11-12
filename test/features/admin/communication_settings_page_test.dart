import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/features/admin/data/communication_settings_errors.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_management_tab.dart';
import 'package:rafiq_academy/features/app_update/presentation/bloc/client_version_gate_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';

class _IdleAuthBloc extends Fake implements AuthBloc {
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => const AuthUnauthenticated();

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() => _controller.close();
}

class _AllowedVersionGate extends Fake implements ClientVersionGateBloc {
  final _controller = StreamController<ClientVersionGateState>.broadcast();

  @override
  ClientVersionGateState get state =>
      const ClientVersionGateState(status: ClientVersionGateStatus.allowed);

  @override
  Stream<ClientVersionGateState> get stream => _controller.stream;

  @override
  void add(ClientVersionCheckRequested event) {}

  @override
  Future<void> close() => _controller.close();
}

/// The communication settings page was removed: it saved a policy that
/// nothing enforced. Stored settings and the data contract are left intact.
void main() {
  late AppRouter appRouter;

  setUp(() {
    appRouter = AppRouter(
      authBloc: _IdleAuthBloc(),
      versionGate: _AllowedVersionGate(),
      onboardingSeen: ValueNotifier(true),
    );
  });

  tearDown(() => appRouter.router.dispose());

  bool isRegistered(String location) => appRouter.router.configuration
      .findMatch(Uri.parse(location))
      .isNotEmpty;

  test('the removed settings route is not registered', () {
    expect(isRegistered('/admin/communication-settings'), isFalse);
  });

  test('every Admin hub destination resolves to a registered route', () {
    final routes = AdminManagementTab.hubRoutes.toList();
    expect(routes, isNotEmpty);
    expect(routes, isNot(contains('/admin/communication-settings')));
    for (final route in routes) {
      expect(isRegistered(route), isTrue, reason: route);
    }
  });

  testWidgets('the Admin hub no longer offers communication settings, but '
      'keeps the communication tools', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AdminManagementTab()));
    await tester.pump();

    expect(find.text('إعدادات التواصل'), findsNothing);
    for (final kept in const [
      'مركز التواصل',
      'الشكاوى',
      'البث الجماعي',
      'الرسائل',
      'صندوق الإشعارات',
    ]) {
      expect(find.text(kept), findsOneWidget, reason: kept);
    }
  });

  test('stored-settings error mapping (still used by the data layer) never '
      'exposes raw codes', () {
    for (final save in [true, false]) {
      for (final code in ['permission-denied', 'unavailable', 'internal']) {
        final m = communicationSettingsErrorMessage(code, save: save);
        expect(m, isNot(contains(code)));
      }
    }
    expect(
      communicationSettingsErrorMessage('unavailable', save: false),
      kCommunicationSettingsOfflineMessage,
    );
  });
}
