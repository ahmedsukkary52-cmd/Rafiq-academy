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

  /// Matches native Android [basma_launch_background] — soft neutral so the
  /// logo artwork is not lost against teal/blue fills.
  static const Color background = AppColors.background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
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
                            color: AppColors.primary,
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
        Text(
          AcademyBranding.shortName,
          style: AppTextStyles.displayLarge.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AcademyBranding.tagline,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
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
        const Icon(
          Icons.wifi_off_rounded,
          color: AppColors.textSecondary,
          size: 36,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () =>
              context.read<AuthBloc>().add(const CheckAuthStatusEvent()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
          onPressed: () => context.read<AuthBloc>().add(const LogoutEvent()),
          child: const Text('تسجيل الدخول بحساب آخر'),
        ),
      ],
    );
  }
}
