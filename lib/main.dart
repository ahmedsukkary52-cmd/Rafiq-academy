import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/injection_container.dart';
import 'core/router/router_app.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/student/presentation/bloc/student_bloc.dart';
import 'features/teacher/presentation/bloc/teacher_bloc.dart';
import 'features/parent/presentation/bloc/parent_bloc.dart';
import 'features/supervisor/presentation/bloc/supervisor_bloc.dart';
import 'features/admin/presentation/bloc/admin_bloc.dart';
import 'features/notifications/presentation/bloc/notifications_bloc.dart';
import 'features/analytics/presentation/bloc/analytics_bloc.dart';
import 'features/awards/presentation/bloc/awards_bloc.dart';
import 'features/calendar/presentation/bloc/calendar_bloc.dart';
import 'features/content/presentation/bloc/content_bloc.dart';
import 'features/chat/presentation/bloc/chat_conversations_bloc.dart';
import 'features/post/presentation/bloc/posts_bloc.dart';
import 'firebase_options.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'shared/theme/app_preferences_controller.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initDependencies();

  final prefs = await SharedPreferences.getInstance();
  final onboardingSeen =
  ValueNotifier<bool>(prefs.getBool(onboardingSeenPrefKey) ?? false);
  final appPreferences = await AppPreferencesController.load(prefs);

  runApp(
    MyApp(onboardingSeen: onboardingSeen, appPreferences: appPreferences),
  );
}

class MyApp extends StatelessWidget {
  final ValueNotifier<bool> onboardingSeen;
  final AppPreferencesController appPreferences;

  const MyApp({
    super.key,
    required this.onboardingSeen,
    required this.appPreferences,
  });

  @override
  Widget build(BuildContext context) {
    final authBloc = sl<AuthBloc>()
      ..add(const CheckAuthStatusEvent());

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authBloc),
        BlocProvider.value(value: sl<StudentBloc>()),
        BlocProvider.value(value: sl<TeacherBloc>()),
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
      child: AppPreferencesScope(
        controller: appPreferences,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: appPreferences.themeMode,
          builder: (context, themeMode, _) {
            return ValueListenableBuilder<AppFontSize>(
              valueListenable: appPreferences.fontSize,
              builder: (context, fontSize, _) {
                return MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  title: 'أكاديمية رفيق',
                  theme: AppTheme.theme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(fontSize.scale),
                      ),
                      child: child!,
                    );
                  },
                  routerConfig: AppRouter(
                    authBloc: authBloc,
                    onboardingSeen: onboardingSeen,
                  ).router,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
