import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/parent_household.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../bloc/parent_state.dart';
import '../parent_destinations.dart';
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';
import '../widgets/parent_user_avatar.dart';

class ParentChildrenPage extends StatelessWidget {
  const ParentChildrenPage({super.key});

  void _reload(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<ParentBloc>().add(LoadChildrenEvent(auth.user.uid));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('أبنائي'),
          automaticallyImplyLeading: false,
        ),
        body: BlocBuilder<ParentBloc, ParentState>(
          buildWhen: (p, c) =>
              p.childrenStatus != c.childrenStatus ||
              p.childrenIds != c.childrenIds ||
              p.childrenError != c.childrenError ||
              p.childrenSnapshots != c.childrenSnapshots,
          builder: (context, state) {
            if (state.childrenStatus == SectionStatus.initial ||
                state.childrenStatus == SectionStatus.loading) {
              return const ParentChildrenListSkeleton();
            }
            if (state.childrenStatus == SectionStatus.error) {
              return AppErrorWidget(
                message: state.childrenError ?? 'تعذر تحميل الأبناء',
                onRetry: () => _reload(context),
              );
            }
            if (state.childrenIds.isEmpty) {
              return const ParentEmptyState(
                icon: Icons.family_restroom_rounded,
                title: 'لا يوجد طلاب مرتبطون بهذا الحساب بعد',
                message:
                    'عند ربط أبنائك بحسابك من قِبل الأكاديمية ستظهر أسماؤهم هنا.',
              );
            }

            final snapshots = state.childrenSnapshots;
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => _reload(context),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: state.childrenIds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final id = state.childrenIds[index];
                  ParentChildSnapshot? snap;
                  for (final s in snapshots) {
                    if (s.studentId == id) {
                      snap = s;
                      break;
                    }
                  }
                  return _ChildCard(
                    studentId: id,
                    snapshot: snap,
                    name: snap?.displayName ?? state.childDisplayName(id),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final String studentId;
  final String name;
  final ParentChildSnapshot? snapshot;

  const _ChildCard({
    required this.studentId,
    required this.name,
    this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final halaqa = snapshot?.halaqaName.trim() ?? '';
    final attendance = parentAttendanceLabel(snapshot?.todayAttendanceStatus);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(name, style: AppTextStyles.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      halaqa.isEmpty ? 'لم تُحدد حلقة بعد' : halaqa,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'اليوم: $attendance',
                        if (snapshot?.teacherName.trim().isNotEmpty == true)
                          'المعلم: ${snapshot!.teacherName}',
                      ].join(' · '),
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ParentUserAvatar(
                name: name,
                imageUrl: snapshot?.profileImageUrl,
                radius: 24,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ParentDestinations.reports(
                    context,
                    studentId: studentId,
                    studentName: name,
                  ),
                  child: const Text('التقارير'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => ParentDestinations.childProfile(
                    context,
                    studentId: studentId,
                    studentName: name,
                  ),
                  child: const Text('عرض الملف الشخصي'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
