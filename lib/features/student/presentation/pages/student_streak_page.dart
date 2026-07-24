import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';

class StudentStreakPage extends StatefulWidget {
  const StudentStreakPage({super.key});

  @override
  State<StudentStreakPage> createState() => _StudentStreakPageState();
}

class _StudentStreakPageState extends State<StudentStreakPage> {
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<StudentBloc>().add(LoadStudentProfileEvent(auth.user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<StudentBloc, StudentState>(
          builder: (context, state) {
            final waitingForProfile =
                state.profile == null &&
                (state.profileStatus == SectionStatus.initial ||
                    state.profileStatus == SectionStatus.loading);

            if (waitingForProfile) {
              return const AppLoadingWidget();
            }

            if (state.profileStatus == SectionStatus.error &&
                state.profile == null) {
              return AppErrorWidget(
                message: state.profileError ?? 'تعذر تحميل بيانات الاستمرارية',
                onRetry: _loadProfile,
              );
            }

            final streak = state.profile?.streakDays ?? 0;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _StreakHero(streak: streak)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                  sliver: SliverToBoxAdapter(
                    child: streak == 0
                        ? const _EmptyStreakCard()
                        : _CurrentStreakCard(streak: streak),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyStreakCard extends StatelessWidget {
  const _EmptyStreakCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        'لا توجد أيام متواصلة حالياً\nستظهر سلسلتك هنا عند تحديثها في ملفك',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  final int streak;

  const _StreakHero({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 382,
      decoration: const BoxDecoration(color: Color(0xFFE9292F)),
      child: Stack(
        children: [
          Positioned(
            top: 74,
            left: -10,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (Navigator.canPop(context))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const Spacer(),
                  const Text('🔥', style: TextStyle(fontSize: 78)),
                  const SizedBox(height: 8),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يوم متواصل 💪',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentStreakCard extends StatelessWidget {
  final int streak;

  const _CurrentStreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        'سلسلتك الحالية $streak يوم متواصل من ملفك.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
