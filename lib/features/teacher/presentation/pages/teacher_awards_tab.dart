import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../awards/presentation/pages/awards_page.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../teacher_home_nav.dart';
import '../widgets/teacher_loading_skeletons.dart';

/// Teacher Home tab for الجوائز — halaqa-scoped, not an aggregate.
class TeacherAwardsTab extends StatefulWidget {
  const TeacherAwardsTab({super.key});

  @override
  State<TeacherAwardsTab> createState() => _TeacherAwardsTabState();
}

class _TeacherAwardsTabState extends State<TeacherAwardsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRoster());
  }

  void _ensureRoster([TeacherState? state]) {
    if (!mounted) return;
    final current = state ?? context.read<TeacherBloc>().state;
    final halaqaId = resolveTeacherAwardsHalaqaId(
      selectedHalaqaId: current.selectedHalaqaId,
      teacherHalaqaIds: current.halaqat.map((h) => h.id).toList(),
    );
    if (halaqaId == null) return;
    if (current.studentsHalaqaId == halaqaId) return;
    context.read<TeacherBloc>().add(LoadHalaqaStudentsEvent(halaqaId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TeacherBloc, TeacherState>(
      listenWhen: (previous, current) =>
          previous.selectedHalaqaId != current.selectedHalaqaId ||
          previous.halaqat != current.halaqat,
      listener: (context, state) => _ensureRoster(state),
      buildWhen: (previous, current) =>
          previous.selectedHalaqaId != current.selectedHalaqaId ||
          previous.halaqat != current.halaqat ||
          previous.halaqatStatus != current.halaqatStatus ||
          previous.halaqatError != current.halaqatError,
      builder: (context, state) {
        if (state.halaqatStatus == SectionStatus.initial ||
            (state.halaqatStatus == SectionStatus.loading &&
                state.halaqat.isEmpty)) {
          return const TeacherAwardsDashboardSkeleton();
        }

        if (state.halaqatStatus == SectionStatus.error &&
            state.halaqat.isEmpty) {
          return AppErrorWidget(
            message: state.halaqatError ?? 'تعذر تحميل الحلقات',
            onRetry: () {
              final auth = context.read<AuthBloc>().state;
              if (auth is! AuthAuthenticated) return;
              context.read<TeacherBloc>().add(
                LoadTeacherHalaqatEvent(auth.user.uid),
              );
            },
          );
        }

        final halaqaId = resolveTeacherAwardsHalaqaId(
          selectedHalaqaId: state.selectedHalaqaId,
          teacherHalaqaIds: state.halaqat.map((h) => h.id).toList(),
        );

        if (halaqaId == null) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Text(
                  'لا توجد حلقة حالياً لعرض الجوائز',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }

        return AwardsPage(
          key: ValueKey(halaqaId),
          halaqaId: halaqaId,
          embedded: true,
        );
      },
    );
  }
}
