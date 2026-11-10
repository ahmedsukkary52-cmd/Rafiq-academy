import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/staff_lifecycle_repository.dart';
import '../admin_format.dart';
import 'admin_halaqa_details_page.dart';
import 'admin_teachers_page.dart' show resolveStaffLifecycleRepository;
import '../widgets/staff_lifecycle_sheet.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_loading_skeletons.dart';
import '../widgets/admin_subpage_scaffold.dart';

/// Academy supervisors with their halaqat and account management.
class AdminSupervisorsPage extends StatefulWidget {
  const AdminSupervisorsPage({super.key, this.staffRepository});

  /// Test seam; defaults to the Firebase-backed repository.
  final StaffLifecycleRepository? staffRepository;

  @override
  State<AdminSupervisorsPage> createState() => _AdminSupervisorsPageState();
}

class _AdminSupervisorsPageState extends State<AdminSupervisorsPage> {
  late final StaffLifecycleRepository _staff =
      widget.staffRepository ?? resolveStaffLifecycleRepository();
  List<StaffMember>? _members;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const LoadAdminDirectoryEvent());
    });
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final list = await _staff.listStaff(AppRoles.supervisor);
      if (mounted) {
        setState(() {
          _members = list;
          _error = null;
        });
      }
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _refresh() async {
    final bloc = context.read<AdminBloc>();
    bloc.add(const LoadAdminDirectoryEvent());
    await Future.wait([
      _loadMembers(),
      bloc.stream.firstWhere((s) => s.directoryStatus != SectionStatus.loading),
    ]);
  }

  Future<void> _manage(StaffMember member) async {
    final changed = await showStaffLifecycleSheet(
      context,
      member: member,
      repository: _staff,
    );
    if (!mounted || !changed) return;
    AppSnackBar.showSuccess(context, 'تم تحديث الحساب');
    context.read<AdminBloc>().add(const LoadAdminDirectoryEvent());
    await _loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: 'المشرفون',
      subtitle: 'مشرفو الأكاديمية وحلقاتهم',
      body: BlocBuilder<AdminBloc, AdminState>(
        buildWhen: (p, c) =>
            p.directoryStatus != c.directoryStatus ||
            p.halaqatDirectory != c.halaqatDirectory,
        builder: (context, state) {
          final members = _members;
          if (members == null && _error == null) {
            return const AdminTeachersListSkeleton();
          }
          if (members == null) {
            return AppErrorWidget(message: _error!, onRetry: _refresh);
          }

          final list = members;
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  AdminPlaceholderCard(
                    icon: Icons.supervisor_account_outlined,
                    title: 'لا مشرفين',
                    message: 'لم يُعثر على حسابات مشرفين مسجّلة.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final staff = list[index];
                final halaqat = state.halaqatDirectory
                    .where((h) => h.supervisorId == staff.uid)
                    .map((h) => h.name)
                    .where((n) => n.isNotEmpty)
                    .toList();
                return _StaffTile(
                  name: staff.name,
                  icon: Icons.supervisor_account,
                  halaqat: halaqat,
                  status: staff.status,
                  onTap: () => _manage(staff),
                  tileKey: Key('supervisor-${staff.uid}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Academy-wide halaqat directory; each entry opens [AdminHalaqaDetailsPage].
class AdminHalaqatDirectoryPage extends StatefulWidget {
  const AdminHalaqatDirectoryPage({super.key});

  @override
  State<AdminHalaqatDirectoryPage> createState() =>
      _AdminHalaqatDirectoryPageState();
}

class _AdminHalaqatDirectoryPageState extends State<AdminHalaqatDirectoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const LoadAdminDirectoryEvent());
    });
  }

  Future<void> _refresh() async {
    final bloc = context.read<AdminBloc>();
    bloc.add(const LoadAdminDirectoryEvent());
    await bloc.stream.firstWhere(
      (s) => s.directoryStatus != SectionStatus.loading,
    );
  }

  static String _person(String id, String name) {
    if (id.isEmpty) return 'غير معيّن';
    return name.isEmpty ? 'بدون اسم' : name;
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: 'الحلقات',
      subtitle: 'دليل حلقات الأكاديمية',
      body: BlocBuilder<AdminBloc, AdminState>(
        buildWhen: (p, c) =>
            p.directoryStatus != c.directoryStatus ||
            p.halaqatDirectory != c.halaqatDirectory,
        builder: (context, state) {
          if (state.directoryStatus == SectionStatus.loading &&
              state.halaqatDirectory.isEmpty) {
            return const AdminTeachersListSkeleton();
          }
          if (state.directoryStatus == SectionStatus.error &&
              state.halaqatDirectory.isEmpty) {
            return AppErrorWidget(
              message: state.directoryError ?? 'تعذر التحميل',
              onRetry: _refresh,
            );
          }

          final list = state.halaqatDirectory;
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  AdminPlaceholderCard(
                    icon: Icons.groups_outlined,
                    title: 'لا حلقات',
                    message: 'لم يُعثر على حلقات مسجّلة في الأكاديمية.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final h = list[index];
                return AppCard(
                  key: Key('halaqa-directory-${h.id}'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminHalaqaDetailsPage(halaqa: h),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              h.name.isEmpty ? 'حلقة بدون اسم' : h.name,
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${formatAdminCount(h.studentCount)} طالب',
                            style: AppTextStyles.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'المعلم: ${_person(h.teacherId, h.teacherName)}',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المشرف: ${_person(h.supervisorId, h.supervisorName)}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final List<String> halaqat;
  final StaffStatus status;
  final VoidCallback onTap;
  final Key tileKey;

  const _StaffTile({
    required this.name,
    required this.icon,
    required this.status,
    required this.onTap,
    required this.tileKey,
    this.halaqat = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: tileKey,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'بدون اسم' : name,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  halaqat.isEmpty
                      ? 'لا حلقات مسندة'
                      : '${formatAdminCount(halaqat.length)} حلقة: ${halaqat.join('، ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StaffStatusBadge(status: status),
        ],
      ),
    );
  }
}
