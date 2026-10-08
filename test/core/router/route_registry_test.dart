import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
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

void main() {
  late AppRouter appRouter;

  setUp(() {
    appRouter = AppRouter(
      authBloc: _IdleAuthBloc(),
      onboardingSeen: ValueNotifier(true),
    );
  });

  tearDown(() => appRouter.router.dispose());

  bool isRegistered(String location) => appRouter.router.configuration
      .findMatch(Uri.parse(location))
      .isNotEmpty;

  test('orphan routes removed in H6 are not registered', () {
    for (final path in const [
      '/student/history',
      '/teacher/calendar',
      '/teacher/content',
    ]) {
      expect(isRegistered(path), isFalse, reason: path);
    }
  });

  test('live surfaces stay registered', () {
    for (final path in [
      AppRoutes.studentContent,
      AppRoutes.admin,
      AppRoutes.supervisor,
      AppRoutes.teacherChat.replaceFirst(':conversationId', 'c1'),
      AppRoutes.teacherStudentProfile('s1'),
      '/teacher/halaqa/h1/analytics',
      '/teacher/halaqa/h1/awards',
    ]) {
      expect(isRegistered(path), isTrue, reason: path);
    }
  });
}
