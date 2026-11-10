import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/academy_branding.dart';
import 'core/di/injection_container.dart';
import 'core/firebase/app_firebase.dart';
import 'core/router/router_app.dart';
import 'core/session/clear_session_projections.dart';
import 'features/app_update/presentation/bloc/client_version_gate_bloc.dart';
import 'features/app_update/presentation/version_gate_session.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/student/presentation/bloc/student_bloc.dart';
import 'features/teacher/presentation/bloc/teacher_bloc.dart';
import 'features/teacher/presentation/teacher_award_grant_scope.dart';
import 'features/parent/presentation/bloc/parent_bloc.dart';
import 'features/supervisor/presentation/bloc/supervisor_bloc.dart';
import 'features/admin/presentation/bloc/admin_bloc.dart';
import 'features/notifications/data/services/fcm_sign_out_preparation.dart';
import 'features/notifications/data/services/fcm_token_registrar.dart';
import 'features/notifications/data/services/offline_notification_open_port.dart';
import 'features/notifications/domain/services/notification_open_port.dart';
import 'features/notifications/presentation/bloc/notifications_bloc.dart';
import 'features/notifications/presentation/notification_deep_links.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/analytics/presentation/bloc/analytics_bloc.dart';
import 'features/awards/domain/award_grant_scope.dart';
import 'features/awards/presentation/bloc/awards_bloc.dart';
import 'features/calendar/presentation/bloc/calendar_bloc.dart';
import 'features/content/presentation/bloc/content_bloc.dart';
import 'features/chat/presentation/bloc/chat_conversations_bloc.dart';
import 'features/post/presentation/bloc/posts_bloc.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'shared/theme/app_locale_config.dart';
import 'shared/theme/app_preferences_controller.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppFirebase();
  await initDependencies();
  if (!useFirebaseEmulator) {
    sl<AuthBloc>().attachSignOutPreparation(
      FcmSignOutPreparation(() => sl<FcmTokenRegistrar>()),
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final onboardingSeen = ValueNotifier<bool>(
    prefs.getBool(onboardingSeenPrefKey) ?? false,
  );
  final appPreferences = await AppPreferencesController.load(prefs);

  runApp(MyApp(onboardingSeen: onboardingSeen, appPreferences: appPreferences));
}

class MyApp extends StatefulWidget {
  final ValueNotifier<bool> onboardingSeen;
  final AppPreferencesController appPreferences;

  const MyApp({
    super.key,
    required this.onboardingSeen,
    required this.appPreferences,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthBloc authBloc = sl<AuthBloc>();

  /// B10 — session restoration waits until this first reports allowed.
  late final ClientVersionGateBloc versionGate = sl<ClientVersionGateBloc>()
    ..add(const ClientVersionCheckRequested());

  /// One router for the app lifetime so push taps can navigate it.
  late final GoRouter _router = AppRouter(
    authBloc: authBloc,
    versionGate: versionGate,
    onboardingSeen: widget.onboardingSeen,
  ).router;

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Award sheets offer the teacher's loaded halaqat for every staff viewer.
  late final AwardGrantScopeSource _awardGrantScope =
      TeacherAwardGrantScopeSource(sl<TeacherBloc>());

  StreamSubscription<ClientVersionGateState>? _versionGateSub;
  late final _authStart = AuthStartAfterGate(
    () => authBloc.add(const CheckAuthStatusEvent()),
  );
  late final AppLifecycleListener _lifecycle;

  StreamSubscription<String>? _pushOpenSub;

  /// A tapped push waiting for authentication to resolve.
  String? _pendingPushType;

  ValueNotifier<bool> get onboardingSeen => widget.onboardingSeen;
  AppPreferencesController get appPreferences => widget.appPreferences;

  @override
  void initState() {
    super.initState();
    _versionGateSub = versionGate.stream.listen(_authStart.onGateState);
    _lifecycle = AppLifecycleListener(
      onResume: () => versionGate.add(const ClientVersionCheckRequested()),
    );
    // Offline FCM is unsupported in Emulator mode (no [DEFAULT] app).
    final NotificationOpenPort opens = useFirebaseEmulator
        ? const OfflineNotificationOpenPort()
        : sl<NotificationOpenPort>();
    _pushOpenSub = opens.openedTypes().listen(_onPushOpened);
    unawaited(
      opens.initialOpenedType().then((type) {
        if (type != null) _onPushOpened(type);
      }),
    );
  }

  @override
  void dispose() {
    _pushOpenSub?.cancel();
    _versionGateSub?.cancel();
    _lifecycle.dispose();
    versionGate.close();
    super.dispose();
  }

  void _onPushOpened(String type) {
    _pendingPushType = type;
    _consumePendingPush();
  }

  void _consumePendingPush() {
    final type = _pendingPushType;
    final auth = authBloc.state;
    if (type == null || auth is! AuthAuthenticated) return;
    _pendingPushType = null;
    final target = NotificationDeepLinks.pushTarget(
      type: type,
      role: auth.user.role,
    );
    if (target != null) _router.push(target);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authBloc),
        BlocProvider.value(value: versionGate),
        BlocProvider.value(value: sl<StudentBloc>()),
        BlocProvider.value(value: sl<TeacherBloc>()),
        RepositoryProvider<AwardGrantScopeSource>.value(
          value: _awardGrantScope,
        ),
        BlocProvider.value(value: sl<ParentBloc>()),
        BlocProvider.value(value: sl<SupervisorBloc>()),
        BlocProvider.value(value: sl<AdminBloc>()),
        BlocProvider.value(value: sl<NotificationsBloc>()),
        BlocProvider.value(value: sl<AnalyticsBloc>()),
        BlocProvider.value(value: sl<AwardsBloc>()),
        BlocProvider.value(value: sl<CalendarBloc>()),
        BlocProvider.value(value: sl<ContentLibraryBloc>()),
        BlocProvider.value(value: sl<ChatConversationsBloc>()),
        BlocProvider.value(value: sl<PostsBloc>()),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current is AuthLogoutFailure ||
            (current is AuthUnauthenticated &&
                previous is! AuthUnauthenticated) ||
            (current is AuthAuthenticated &&
                (previous is! AuthAuthenticated ||
                    previous.user.uid != current.user.uid)),
        listener: (context, state) {
          if (state is AuthLogoutFailure) {
            _messengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(state.message, textAlign: TextAlign.right),
              ),
            );
            return;
          }
          if (state is AuthAuthenticated) {
            // WA-13 / C11: the app's single FCM registration point.
            // FCM has no emulator; its tokens belong to the production project.
            if (!useFirebaseEmulator) {
              unawaited(sl<FcmTokenRegistrar>().onSignedIn(state.user.uid));
            }
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _consumePendingPush(),
            );
            return;
          }
          // H1 / A-H1: singleton role & capability projections must not
          // survive logout on shared devices.
          _pendingPushType = null;
          clearSessionProjections(context);
          if (!useFirebaseEmulator) {
            unawaited(sl<FcmTokenRegistrar>().onSignedOut());
          }
        },
        child: AppPreferencesScope(
          controller: appPreferences,
          child: ValueListenableBuilder<AppFontSize>(
            valueListenable: appPreferences.fontSize,
            builder: (context, fontSize, _) {
              return MaterialApp.router(
                scaffoldMessengerKey: _messengerKey,
                debugShowCheckedModeBanner: false,
                title: AcademyBranding.displayName,
                // D15 — Arabic + RTL only (UI-1).
                locale: AppLocaleConfig.locale,
                supportedLocales: AppLocaleConfig.supportedLocales,
                localizationsDelegates: AppLocaleConfig.localizationsDelegates,
                theme: AppTheme.theme,
                // Infrastructure retained; product always uses light (D15).
                darkTheme: AppTheme.theme,
                themeMode: ThemeMode.light,
                builder: (context, child) {
                  return Directionality(
                    textDirection: AppLocaleConfig.textDirection,
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(fontSize.scale)),
                      child: VersionGateSessionGuard(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
                routerConfig: _router,
              );
            },
          ),
        ),
      ),
    );
  }
}
