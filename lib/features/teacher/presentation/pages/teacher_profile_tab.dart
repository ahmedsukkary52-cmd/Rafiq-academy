import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_state.dart';

class TeacherProfileTab extends StatelessWidget {
  const TeacherProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final phone = user?.phone.trim() ?? '';
    final email = user?.email?.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: AppColors.primary,
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: AppSizes.paddingXL,
              ),
              child: Column(
                children: [
                  UserAvatar(
                    name: user?.name ?? 'م',
                    imageUrl: user?.profileImageUrl,
                    size: AppSizes.avatarXL,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.name.trim().isNotEmpty == true
                        ? 'أ. ${user!.name}'
                        : 'المعلم',
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'معلم تحفيظ',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ] else if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: BlocBuilder<TeacherBloc, TeacherState>(
                buildWhen: (previous, current) =>
                    previous.halaqatStatus != current.halaqatStatus ||
                    previous.halaqat != current.halaqat ||
                    previous.halaqatError != current.halaqatError,
                builder: (context, state) {
                  if (state.halaqatStatus == SectionStatus.loading ||
                      state.halaqatStatus == SectionStatus.initial) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: AppLoadingWidget(),
                    );
                  }

                  if (state.halaqatStatus == SectionStatus.error) {
                    return Text(
                      state.halaqatError ?? 'تعذر تحميل الإحصاءات',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }

                  final halaqaCount = '${state.halaqat.length}';
                  final studentCount =
                      '${state.halaqat.fold<int>(0, (sum, h) => sum + h.studentIds.length)}';

                  return Row(
                    children: [
                      _StatCard(value: studentCount, label: 'طالب'),
                      const SizedBox(width: 12),
                      _StatCard(value: halaqaCount, label: 'حلقات'),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
              ),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: _LogoutTile(
                  onTap: () {
                    context.read<AuthBloc>().add(const LogoutEvent());
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('أكاديمية رفيق', style: AppTextStyles.labelSmall),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingM,
          vertical: 14,
        ),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
            const Spacer(),
            Text(
              'تسجيل الخروج',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.error),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
