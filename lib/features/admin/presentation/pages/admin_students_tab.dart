import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/admin_halaqa_roster_entity.dart';
import '../admin_format.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_loading_skeletons.dart';

class AdminStudentsTab extends StatefulWidget {
  const AdminStudentsTab({super.key});

  @override
  State<AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends State<AdminStudentsTab> {
  String _query = '';
  final _expanded = <String>{};
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<AdminBloc>();
      bloc.add(const LoadStudentRosterEvent());
      if (bloc.state.statsStatus != SectionStatus.loaded) {
        bloc.add(const LoadAcademyStatsEvent());
      }
    });
  }

  int _totalStudents(List<AdminHalaqaRosterEntity> roster) {
    return roster.fold(0, (sum, h) => sum + h.students.length);
  }

  List<AdminHalaqaRosterEntity> _filtered(
    List<AdminHalaqaRosterEntity> roster,
  ) {
    if (_query.trim().isEmpty) return roster;
    final q = _query.trim().toLowerCase();
    return roster
        .map((h) {
          final students = h.students
              .where(
                (s) =>
                    s.name.toLowerCase().contains(q) ||
                    (s.phone ?? '').contains(q) ||
                    s.uid.contains(q),
              )
              .toList();
          if (students.isEmpty && !h.name.toLowerCase().contains(q)) {
            return null;
          }
          return AdminHalaqaRosterEntity(
            id: h.id,
            name: h.name,
            teacherId: h.teacherId,
            supervisorId: h.supervisorId,
            status: h.status,
            students: students.isEmpty ? h.students : students,
          );
        })
        .whereType<AdminHalaqaRosterEntity>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocBuilder<AdminBloc, AdminState>(
            buildWhen: (p, c) =>
                p.rosterStatus != c.rosterStatus ||
                p.studentRoster != c.studentRoster ||
                p.stats != c.stats,
            builder: (context, state) {
              final total =
                  state.stats?.totalStudents ??
                  _totalStudents(state.studentRoster);
              final roster = _filtered(state.studentRoster);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'الإشعارات',
                                onPressed: () => context.push(
                                  '${AppRoutes.admin}/notifications',
                                ),
                                icon: const Icon(
                                  Icons.notifications_none_rounded,
                                ),
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'إدارة الطلاب',
                                    style: AppTextStyles.headlineMedium
                                        .copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    '${formatAdminCount(total)} طالب في ${formatAdminCount(state.studentRoster.length)} حلقة',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AdminSearchField(
                            controller: _searchCtrl,
                            hint: 'ابحث باسم الطالب أو رقم الجوال',
                            onChanged: (v) => setState(() => _query = v),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'طلبات التسجيل',
                                  onPressed: () =>
                                      context.push(AppRoutes.adminRegistration),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppButton(
                                  label: 'قبول طالب',
                                  onPressed: () =>
                                      context.push('${AppRoutes.admin}/admit'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (state.rosterStatus == SectionStatus.loading)
                    const SliverFillRemaining(
                      child: AdminStudentsRosterSkeleton(),
                    )
                  else if (state.rosterStatus == SectionStatus.error)
                    SliverFillRemaining(
                      child: AppErrorWidget(
                        message: state.rosterError ?? 'تعذر تحميل القائمة',
                        onRetry: () => context.read<AdminBloc>().add(
                          const LoadStudentRosterEvent(),
                        ),
                      ),
                    )
                  else if (roster.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: AdminPlaceholderCard(
                            icon: Icons.search_off_outlined,
                            title: 'لا توجد نتائج',
                            message: _query.trim().isEmpty
                                ? 'لا توجد حلقات أو طلاب مسجلون بعد.'
                                : 'لا توجد حلقات أو طلاب مطابقون للبحث.',
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final h = roster[index];
                        final expanded = _expanded.contains(h.id);
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            index == 0 ? 0 : 8,
                            20,
                            index == roster.length - 1 ? 24 : 0,
                          ),
                          child: AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusL,
                                  ),
                                  onTap: () => setState(() {
                                    if (expanded) {
                                      _expanded.remove(h.id);
                                    } else {
                                      _expanded.add(h.id);
                                    }
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.menu_book_outlined,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                h.name,
                                                style: AppTextStyles.titleMedium
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              Text(
                                                '${formatAdminCount(h.students.length)} طالب',
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AdminStatusBadge(
                                          label: h.status == 'active'
                                              ? 'نشطة'
                                              : h.status,
                                          color: AppColors.success,
                                          bg: AppColors.successBg,
                                        ),
                                        Icon(
                                          expanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: AppColors.textHint,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (expanded && h.students.isNotEmpty)
                                  ...h.students.map(
                                    (s) =>
                                        _StudentRow(student: s, halaqaId: h.id),
                                  ),
                                if (expanded && h.students.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'لا يوجد طلاب في هذه الحلقة',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: roster.length),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final AdminRosterStudentEntity student;
  final String halaqaId;

  const _StudentRow({required this.student, required this.halaqaId});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.adminStudentProfile(student.uid, halaqaId: halaqaId),
        ),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surfaceGrey,
                backgroundImage: student.profileImageUrl != null
                    ? NetworkImage(student.profileImageUrl!)
                    : null,
                child: student.profileImageUrl == null
                    ? Text(
                        student.name.isNotEmpty
                            ? student.name.characters.first
                            : '?',
                        style: const TextStyle(color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (student.phone != null && student.phone!.isNotEmpty)
                      Text(
                        student.phone!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              AdminStatusBadge(
                label: student.isActive ? 'نشط' : 'موقوف',
                color: student.isActive ? AppColors.success : AppColors.warning,
                bg: student.isActive
                    ? AppColors.successBg
                    : const Color(0xFFFFF3E0),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
