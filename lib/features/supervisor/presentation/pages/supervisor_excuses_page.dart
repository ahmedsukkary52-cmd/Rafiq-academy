import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

/// Read-only استئذان projection for assigned halaqat (W7).
/// Accept/Reject write ownership remains teacher — not wired here.
class SupervisorExcusesPage extends StatelessWidget {
  const SupervisorExcusesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SupervisorSubpageScaffold(
      title: 'الاعتذارات',
      body: BlocBuilder<SupervisorBloc, SupervisorState>(
        buildWhen: (p, c) =>
            p.absenceRequestsStatus != c.absenceRequestsStatus ||
            p.absenceRequests != c.absenceRequests ||
            p.absenceRequestsError != c.absenceRequestsError,
        builder: (context, state) {
          if (state.absenceRequestsStatus == SectionStatus.initial ||
              state.absenceRequestsStatus == SectionStatus.loading) {
            return const AppLoadingWidget();
          }
          if (state.absenceRequestsStatus == SectionStatus.error) {
            return AppErrorWidget(
              message: state.absenceRequestsError ?? 'تعذر تحميل الاعتذارات',
              onRetry: () {
                final auth = context.read<AuthBloc>().state;
                if (auth is! AuthAuthenticated) return;
                context.read<SupervisorBloc>().add(
                  LoadSupervisedAbsenceRequestsEvent(
                    supervisorId: auth.user.uid,
                    date: DateTime.now(),
                  ),
                );
              },
            );
          }
          final items = state.absenceRequests;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event_busy_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد طلبات استئذان اليوم في حلقاتك',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _ExcuseTile(request: items[i]),
          );
        },
      ),
    );
  }
}

class _ExcuseTile extends StatelessWidget {
  final AbsenceRequestEntity request;

  const _ExcuseTile({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          request.studentId,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          [
            if (request.halaqaId.trim().isNotEmpty) 'حلقة: ${request.halaqaId}',
            if (request.reason.trim().isNotEmpty) request.reason,
            'الحالة: ${request.status.name}',
          ].join('\n'),
        ),
        isThreeLine: true,
      ),
    );
  }
}
