import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/halaqa_schedule_label.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';

class TeacherClassDetailPage extends StatefulWidget {
  final String halaqaId;

  const TeacherClassDetailPage({super.key, required this.halaqaId});

  @override
  State<TeacherClassDetailPage> createState() => _TeacherClassDetailPageState();
}

class _TeacherClassDetailPageState extends State<TeacherClassDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<TeacherBloc>().add(LoadHalaqaStudentsEvent(widget.halaqaId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<TeacherBloc>().state;
      if (state.halaqatStatus == SectionStatus.initial) {
        _retryHalaqat();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  HalaqaEntity? _findHalaqa(TeacherState state) {
    for (final h in state.halaqat) {
      if (h.id == widget.halaqaId) return h;
    }
    return null;
  }

  void _retryHalaqat() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<TeacherBloc>().add(LoadTeacherHalaqatEvent(auth.user.uid));
  }

  Future<void> _openMeetingLink(String rawLink) async {
    final link = rawLink.trim();
    if (link.isEmpty) {
      AppSnackBar.showInfo(context, 'رابط الحصة غير متاح');
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null ||
        !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
      AppSnackBar.showError(context, 'رابط الحصة غير صالح');
      return;
    }
    final launched =
        await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      AppSnackBar.showError(context, 'تعذر فتح رابط الحصة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeacherBloc, TeacherState>(
      builder: (context, state) {
        final halaqa = _findHalaqa(state);

        if (state.halaqatStatus == SectionStatus.loading ||
            state.halaqatStatus == SectionStatus.initial) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('الحلقة')),
            body: const AppLoadingWidget(),
          );
        }

        if (state.halaqatStatus == SectionStatus.error) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('الحلقة')),
            body: AppErrorWidget(
              message: state.halaqatError ?? 'تعذر تحميل بيانات الحلقة',
              onRetry: _retryHalaqat,
            ),
          );
        }

        if (state.halaqatStatus == SectionStatus.loaded && halaqa == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('الحلقة')),
            body: AppErrorWidget(
              message: 'لم يتم العثور على بيانات الحلقة',
              onRetry: _retryHalaqat,
            ),
          );
        }

        final scheduleLabel = halaqa == null
            ? null
            : halaqaScheduleLabel(halaqa.schedule);
        final meetingLink = halaqa?.meetingLink.trim() ?? '';

        return Scaffold(
          backgroundColor: AppColors.background,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: meetingLink.isNotEmpty || scheduleLabel != null
                    ? 180
                    : 140,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                title: Text(halaqa?.name ?? 'الحلقة'),
                flexibleSpace: FlexibleSpaceBar(
                  background: _HalaqaStatsHeader(
                    studentCount: state.studentsStatus == SectionStatus.loaded
                        ? state.students.length
                        : (halaqa?.studentIds.length ?? 0),
                    scheduleLabel: scheduleLabel,
                    meetingLink: meetingLink.isEmpty ? null : meetingLink,
                    onJoinMeeting: meetingLink.isEmpty
                        ? null
                        : () => _openMeetingLink(meetingLink),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'الطلاب'),
                      Tab(text: 'الحضور'),
                      Tab(text: 'التقييمات'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _StudentsTab(
                  state: state,
                  searchQuery: _searchQuery,
                  onSearch: (q) => setState(() => _searchQuery = q),
                  halaqaId: widget.halaqaId,
                ),
                Center(
                  child: AppButton(
                    label: 'فتح سجل الحضور',
                    onPressed: () =>
                        context.push('/teacher/attendance/${widget.halaqaId}'),
                    width: 200,
                  ),
                ),
                Center(
                  child: AppButton(
                    label: 'فتح التقييمات',
                    onPressed: () => context.push(
                      '/teacher/halaqa/${widget.halaqaId}/evaluations',
                    ),
                    width: 200,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HalaqaStatsHeader extends StatelessWidget {
  final int studentCount;
  final String? scheduleLabel;
  final String? meetingLink;
  final VoidCallback? onJoinMeeting;

  const _HalaqaStatsHeader({
    required this.studentCount,
    this.scheduleLabel,
    this.meetingLink,
    this.onJoinMeeting,
  });

  @override
  Widget build(BuildContext context) {
    final hasSchedule =
        scheduleLabel != null && scheduleLabel!.trim().isNotEmpty;
    final hasLink = meetingLink != null && meetingLink!.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.paddingM,
          48,
          AppSizes.paddingM,
          AppSizes.paddingM,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _HeaderStat(value: '$studentCount', label: 'طالب'),
            if (hasSchedule) ...[
              const SizedBox(height: 8),
              Text(
                scheduleLabel!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
            if (hasLink && onJoinMeeting != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onJoinMeeting,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text(
                  'انضم للحصة',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _StudentsTab extends StatelessWidget {
  final TeacherState state;
  final String searchQuery;
  final void Function(String) onSearch;
  final String halaqaId;

  const _StudentsTab({
    required this.state,
    required this.searchQuery,
    required this.onSearch,
    required this.halaqaId,
  });

  Future<void> _onRefresh(BuildContext context) async {
    final bloc = context.read<TeacherBloc>();
    bloc.add(LoadHalaqaStudentsEvent(halaqaId));
    await bloc.stream.firstWhere(
      (s) =>
          s.studentsStatus == SectionStatus.loaded ||
          s.studentsStatus == SectionStatus.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (state.studentsStatus == SectionStatus.loading ||
        state.studentsStatus == SectionStatus.initial) {
      return const AppLoadingWidget();
    }

    if (state.studentsStatus == SectionStatus.error) {
      return AppErrorWidget(
        message: state.studentsError ?? 'حدث خطأ',
        onRetry: () =>
            context.read<TeacherBloc>().add(LoadHalaqaStudentsEvent(halaqaId)),
      );
    }

    final students = searchQuery.isEmpty
        ? state.students
        : state.students.where((s) => s.name.contains(searchQuery)).toList();

    if (state.students.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _onRefresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: const Center(
                child: Text(
                  'لا يوجد طلاب في هذه الحلقة',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _onRefresh(context),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: AppTextField(
              hint: 'بحث في الطلاب...',
              onChanged: onSearch,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textHint,
              ),
            ),
          ),
          Expanded(
            child: students.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      Center(
                        child: Text(
                          'لا نتائج للبحث',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                    ),
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      return _StudentCard(
                        student: students[i],
                        halaqaId: halaqaId,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final HalaqaStudentSummaryEntity student;
  final String halaqaId;

  const _StudentCard({required this.student, required this.halaqaId});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Row(
            children: [
              _OutlinedChip(
                label: 'منح شارة',
                onTap: () => context.push('/teacher/halaqa/$halaqaId/awards'),
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              _OutlinedChip(
                label: 'تقييم',
                onTap: () =>
                    context.push('/teacher/halaqa/$halaqaId/evaluations'),
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _OutlinedChip(
                label: 'الملف الشخصي',
                onTap: () => context.push('/teacher/student/${student.uid}'),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(student.name, style: AppTextStyles.titleLarge),
              const SizedBox(height: 2),
              _TagChip(
                label: 'المستوى ${student.level}',
                color: AppColors.primaryLight,
                textColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(width: 12),
          UserAvatar(name: student.name),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _TagChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _OutlinedChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _OutlinedChip({
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(_, __, ___) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}
