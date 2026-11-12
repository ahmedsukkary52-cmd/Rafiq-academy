import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/academy_branding.dart';
import '../../../../shared/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_widgets.dart';

/// Session restore screen. Routing is driven by the router redirect; Splash
/// only renders progress, or a retry when Firebase could not be reached.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _SplashMark(),
                const SizedBox(height: 64),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) => state is AuthStartupFailure
                      ? _StartupRetry(message: state.message)
                      : const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AcademyLogo(size: 120),
        const SizedBox(height: 24),
        const Text(
          AcademyBranding.shortName,
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AcademyBranding.tagline,
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _StartupRetry extends StatelessWidget {
  final String message;

  const _StartupRetry({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 36),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
          ),
          onPressed: () =>
              context.read<AuthBloc>().add(const CheckAuthStatusEvent()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: () => context.read<AuthBloc>().add(const LogoutEvent()),
          child: const Text('تسجيل الدخول بحساب آخر'),
        ),
      ],
    );
  }
}
