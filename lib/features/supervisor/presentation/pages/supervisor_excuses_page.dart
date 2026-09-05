import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/absence_request_projection.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../domain/repositories/parent_repository.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_loading_skeletons.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

/// Read-only استئذان projection for assigned halaqat (W7).
/// Accept/Reject write ownership remains teacher — not wired here.
class SupervisorExcusesPage extends StatefulWidget {
  const SupervisorExcusesPage({super.key});

  @override
  State<SupervisorExcusesPage> createState() => _SupervisorExcusesPageState();
}

class _SupervisorExcusesPageState extends State<SupervisorExcusesPage> {
  Map<String, String> _names = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  void _ensureLoaded() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final bloc = context.read<SupervisorBloc>();
    if (bloc.state.absenceRequestsStatus == SectionStatus.initial) {
      bloc.add(
        LoadSupervisedAbsenceRequestsEvent(
          supervisorId: auth.user.uid,
          date: DateTime.now(),
        ),
      );
    }
    _resolveNames(bloc.state.absenceRequests);
  }

  Future<void> _resolveNames(List<AbsenceRequestEntity> requests) async {
    final ids = <String>{
      for (final r in requests) r.studentId.trim(),
    }.where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return;
    final result = await sl<SupervisorRepository>().getUserDisplayNames(ids);
    if (!mounted) return;
    result.fold((_) {}, (map) {
      setState(() => _names = {..._names, ...map});
    });
  }

  String _halaqaName(String id, SupervisorState state) {
    for (final h in state.halaqat) {
      if (h.id == id) return h.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return SupervisorSubpageScaffold(
      title: 'الاعتذارات',
      body: BlocConsumer<SupervisorBloc, SupervisorState>(
        listenWhen: (p, c) => p.absenceRequests != c.absenceRequests,
        listener: (context, state) => _resolveNames(state.absenceRequests),
        buildWhen: (p, c) =>
            p.absenceRequestsStatus != c.absenceRequestsStatus ||
            p.absenceRequests != c.absenceRequests ||
            p.absenceRequestsError != c.absenceRequestsError ||
            p.halaqat != c.halaqat,
        builder: (context, state) {
          if (state.absenceRequestsStatus == SectionStatus.initial ||
              state.absenceRequestsStatus == SectionStatus.loading) {
            return const SupervisorCenteredListSkeleton();
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
                    const SizedBox(height: 8),
                    Text(
                      'القبول/الرفض لمعلم الحلقة — هذه الشاشة للعرض فقط',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textHint,
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
            itemBuilder: (context, i) {
              final request = items[i];
              final studentName =
                  _names[request.studentId] ?? request.studentId;
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          AbsenceRequestProjection.statusLabel(request.status),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatDateDmy(request.date),
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      studentName,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'حلقة: ${_halaqaName(request.halaqaId, state)}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (request.reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        request.reason,
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.right,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'عرض فقط — قرار الاستئذان لمعلم الحلقة',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
