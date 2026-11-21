import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/academy_data_revision.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/domain/arabic_search_normalizer.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student_search/data/datasources/student_search_remote_datasource.dart';
import '../../../student_search/domain/entities/student_search_entry.dart';
import '../../domain/entities/admin_halaqa_roster_entity.dart';
import '../admin_format.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_loading_skeletons.dart';

typedef AdminStudentDirectorySearch =
    Future<List<StudentSearchEntry>> Function(String query);

class AdminStudentsTab extends StatefulWidget {
  const AdminStudentsTab({super.key, this.search});

  /// Server prefix search over the normalized `studentSearch` projection.
  final AdminStudentDirectorySearch? search;

  @override
  State<AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends State<AdminStudentsTab> {
  String _query = '';
  final _expanded = <String>{};
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  int _searchGeneration = 0;
  bool _searching = false;
  List<StudentSearchEntry> _directory = const [];

  @override
  void dispose() {
    AcademyDataRevision.structure.removeListener(_onStructureChanged);
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStructureChanged() {
    if (!mounted) return;
    context.read<AdminBloc>()
      ..add(const LoadStudentRosterEvent())
      ..add(const LoadAcademyStatsEvent());
  }

  @override
  void initState() {
    super.initState();
    AcademyDataRevision.structure.addListener(_onStructureChanged);
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

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    final q = value.trim();
    if (ArabicSearchNormalizer.normalize(q).length < 2) {
      setState(() {
        _directory = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final generation = ++_searchGeneration;
    setState(() => _searching = true);
    try {
      final results = await (widget.search ?? _defaultSearch)(q);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _directory = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _directory = const [];
        _searching = false;
      });
    }
  }

  static Future<List<StudentSearchEntry>> _defaultSearch(String q) =>
      StudentSearchRemoteDatasourceImpl(
        firestore: sl<FirebaseFirestore>(),
      ).searchAll(query: q);

  List<AdminHalaqaRosterEntity> _filtered(
    List<AdminHalaqaRosterEntity> roster,
  ) {
    final q = ArabicSearchNormalizer.normalize(_query);
    if (q.isEmpty) return roster;
    bool matches(String text) =>
        ArabicSearchNormalizer.normalize(text).contains(q);
    return roster
        .map((h) {
          final students = h.students.where((s) => matches(s.name)).toList();
          if (students.isEmpty && !matches(h.name)) {
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

  /// Academy-wide matches the halaqa roster above does not already show
  /// (e.g. students not yet assigned to a halaqa).
  List<Widget> _directorySection(List<AdminHalaqaRosterEntity> roster) {
    if (ArabicSearchNormalizer.normalize(_query).length < 2) return const [];
    final shown = {
      for (final h in _filtered(roster))
        for (final s in h.students) s.uid,
    };
    final extra = _directory
        .where((e) => !shown.contains(e.studentId))
        .toList();
    if (_searching) {
      return const [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      ];
    }
    if (extra.isEmpty) return const [];
    return [
      Text(
        'نتائج أخرى في الأكاديمية',
        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      for (final e in extra)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            key: Key('directory-${e.studentId}'),
            onTap: () => context.push(
              AppRoutes.adminStudentProfile(e.studentId, halaqaId: e.halaqaId),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    e.fullName.isNotEmpty ? e.fullName.characters.first : '?',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.fullName.isEmpty ? 'طالب' : e.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        e.halaqaName.isNotEmpty
                            ? e.halaqaName
                            : 'غير مسجّل في حلقة',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocListener<AdminBloc, AdminState>(
        listenWhen: (previous, current) =>
            previous.toggleAccountStatus != current.toggleAccountStatus ||
            previous.rosterStatus != current.rosterStatus,
        listener: (context, state) {
          if (state.toggleAccountStatus == SubmissionStatus.success) {
            if (state.rosterStatus == SectionStatus.loaded) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تفعيل/تعطيل الطالب بنجاح')),
              );
            } else if (state.rosterStatus == SectionStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم تغيير الحالة، لكن فشل تحديث القائمة: ${state.rosterError}',
                  ),
                ),
              );
            }
          } else if (state.toggleAccountStatus == SubmissionStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل تغيير الحالة: ${state.toggleAccountError}'),
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            bottom: false,
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'إدارة الطلاب',
                                        textAlign: TextAlign.right,
                                        style: AppTextStyles.headlineMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      Text(
                                        '${formatAdminCount(total)} طالب في ${formatAdminCount(state.studentRoster.length)} حلقة',
                                        textAlign: TextAlign.right,
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'الإشعارات',
                                  onPressed: () => context.push(
                                    '${AppRoutes.admin}/notifications',
                                  ),
                                  icon: const Icon(
                                    Icons.notifications_none_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AdminSearchField(
                              key: const Key('admin-students-search'),
                              controller: _searchCtrl,
                              hint: 'ابحث باسم الطالب أو الحلقة',
                              onChanged: _onQueryChanged,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    key: const Key('students-open-onboarding'),
                                    label: 'تسجيل طالب جديد',
                                    onPressed: () => context.push(
                                      AppRoutes.adminOnboardStudent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AppButton(
                                    label: 'طلبات التعيين',
                                    onPressed: () => context.push(
                                      AppRoutes.adminRegistration,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'الطالب يُنشأ مع ولي أمر وحلقة من «تسجيل طالب جديد». '
                              'طلبات التعيين للطلبات الواردة من خارج الإنشاء المباشر.',
                              textAlign: TextAlign.right,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._directorySection(state.studentRoster),
                          ],
                        ),
                      ),
                    ),
                    if (state.rosterStatus == SectionStatus.loading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: AdminStudentsRosterSkeleton(),
                        ),
                      )
                    else if (state.rosterStatus == SectionStatus.error)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: AppErrorWidget(
                            message: state.rosterError ?? 'تعذر تحميل القائمة',
                            onRetry: () => context.read<AdminBloc>().add(
                              const LoadStudentRosterEvent(),
                            ),
                          ),
                        ),
                      )
                    else if (roster.isEmpty)
                      SliverToBoxAdapter(
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                                  style: AppTextStyles
                                                      .titleMedium
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                                Text(
                                                  '${formatAdminCount(h.students.length)} طالب',
                                                  style: AppTextStyles
                                                      .labelSmall
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
                                                : 'غير نشطة',
                                            color: h.status == 'active'
                                                ? AppColors.success
                                                : AppColors.warning,
                                            bg: h.status == 'active'
                                                ? AppColors.successBg
                                                : AppColors.warning.withValues(
                                                    alpha: 0.12,
                                                  ),
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
                                      (s) => _StudentRow(
                                        student: s,
                                        halaqaId: h.id,
                                      ),
                                    ),
                                  if (expanded && h.students.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        'لا يوجد طلاب في هذه الحلقة',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
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
                child: Text(
                  student.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
              // Toggle active/inactive button
              BlocBuilder<AdminBloc, AdminState>(
                buildWhen: (previous, current) =>
                    previous.toggleAccountStatus != current.toggleAccountStatus,
                builder: (context, state) => IconButton(
                  icon: Icon(
                    student.isActive ? Icons.lock_open : Icons.lock,
                    color: student.isActive
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  tooltip: student.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب',
                  onPressed:
                      state.toggleAccountStatus == SubmissionStatus.submitting
                      ? null
                      : () => context.read<AdminBloc>().add(
                          ToggleAccountStatusEvent(
                            uid: student.uid,
                            isActive: !student.isActive,
                          ),
                        ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
