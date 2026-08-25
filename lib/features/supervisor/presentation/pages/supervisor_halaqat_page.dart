import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_state.dart';
import '../supervisor_destinations.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

class SupervisorHalaqatPage extends StatelessWidget {
  const SupervisorHalaqatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SupervisorSubpageScaffold(
      title: 'الحلقات',
      body: BlocBuilder<SupervisorBloc, SupervisorState>(
        buildWhen: (p, c) =>
            p.halaqatStatus != c.halaqatStatus ||
            p.halaqat != c.halaqat ||
            p.halaqatError != c.halaqatError,
        builder: (context, state) {
          if (state.halaqatStatus == SectionStatus.initial ||
              state.halaqatStatus == SectionStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.halaqatStatus == SectionStatus.error) {
            return AppErrorWidget(
              message: state.halaqatError ?? 'تعذر تحميل الحلقات',
            );
          }
          if (state.halaqat.isEmpty) {
            return Center(
              child: Text(
                'لا توجد حلقات ضمن إشرافك',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: state.halaqat.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final h = state.halaqat[i];
              return _HalaqaTile(
                halaqa: h,
                onTap: () => SupervisorDestinations.halaqaDetail(
                  context,
                  halaqaId: h.id,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HalaqaTile extends StatelessWidget {
  final HalaqaEntity halaqa;
  final VoidCallback onTap;

  const _HalaqaTile({required this.halaqa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      halaqa.name,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${halaqa.studentIds.length} طالب',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: halaqa.status),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final active = status.trim().toLowerCase() == 'active';
    final label = active ? 'نشطة' : (status.trim().isEmpty ? '—' : status);
    final bg = active ? const Color(0xFFE8F5E9) : AppColors.surfaceGrey;
    final fg = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
