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

  void _openSendAssignmentSheet(
    BuildContext context, {
    required int studentCount,
  }) {
    if (studentCount <= 0) {
      AppSnackBar.showError(
        context,
        'لا يوجد طلاب في هذه الحلقة لإرسال التكليف',
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<TeacherBloc>(),
        child: _SendAssignmentSheet(halaqaId: widget.halaqaId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeacherBloc, TeacherState>(
      buildWhen: (previous, current) =>
          previous.halaqatStatus != current.halaqatStatus ||
          previous.halaqat != current.halaqat ||
          previous.halaqatError != current.halaqatError,
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
                actions: [
                  TextButton(
                    onPressed: halaqa == null
                        ? null
                        : () => _openSendAssignmentSheet(
                            context,
                            studentCount: halaqa.studentIds.length,
                          ),
                    child: const Text(
                      'تكليف',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'NotoNaskhArabic',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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

/// إرسال تكليف يومي لكل طلاب الحلقة (Slice 1 — W1).
/// dueDate = نهاية اليوم المختار حتى يصبح «التكليف الحالي» الأحدث بحسب D7.
class _SendAssignmentSheet extends StatefulWidget {
  final String halaqaId;

  const _SendAssignmentSheet({required this.halaqaId});

  @override
  State<_SendAssignmentSheet> createState() => _SendAssignmentSheetState();
}

class _SendAssignmentSheetState extends State<_SendAssignmentSheet> {
  final _memorizationCtrl = TextEditingController();
  final _reviewCtrl = TextEditingController();
  late DateTime _dueDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dueDay = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _memorizationCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  DateTime get _dueDateEndOfDay =>
      DateTime(_dueDay.year, _dueDay.month, _dueDay.day, 23, 59, 59);

  String get _dueDayLabel {
    final d = _dueDay;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (d == todayOnly) return 'اليوم';
    final tomorrow = todayOnly.add(const Duration(days: 1));
    if (d == tomorrow) return 'غداً';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDueDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDay,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'موعد التسليم',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueDay = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _submit() {
    final memorization = _memorizationCtrl.text.trim();
    final review = _reviewCtrl.text.trim();
    if (memorization.isEmpty && review.isEmpty) {
      AppSnackBar.showError(context, 'أدخل نطاق الحفظ أو المراجعة على الأقل');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول لإرسال التكليف');
      return;
    }

    context.read<TeacherBloc>().add(
      SendAssignmentEvent(
        halaqaId: widget.halaqaId,
        newMemorizationRange: memorization,
        reviewRange: review,
        dueDate: _dueDateEndOfDay,
        teacherId: authState.user.uid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TeacherBloc, TeacherState>(
      listenWhen: (prev, curr) =>
          prev.assignmentSubmissionStatus != curr.assignmentSubmissionStatus,
      listener: (context, state) {
        if (state.assignmentSubmissionStatus == SubmissionStatus.success) {
          Navigator.pop(context);
          AppSnackBar.showSuccess(context, 'تم إرسال التكليف للطلاب');
          context.read<TeacherBloc>().add(
            const ResetAssignmentSubmissionEvent(),
          );
        } else if (state.assignmentSubmissionStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.assignmentSubmissionError ?? 'فشل إرسال التكليف',
          );
          context.read<TeacherBloc>().add(
            const ResetAssignmentSubmissionEvent(),
          );
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusXL),
          ),
        ),
        padding: EdgeInsets.only(
          top: AppSizes.paddingL,
          left: AppSizes.paddingM,
          right: AppSizes.paddingM,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingL,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('تكليف جديد', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'يُنشأ تكليف مستقل لكل طالب. يظهر للطالب الأحدث حسب موعد التسليم.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 20),
              const _SheetLabel('نطاق الحفظ الجديد'),
              AppTextField(
                hint: 'مثال: سورة الملك ١-١٠',
                controller: _memorizationCtrl,
              ),
              const SizedBox(height: 16),
              const _SheetLabel('نطاق المراجعة'),
              AppTextField(hint: 'مثال: سورة يس ١-٢٠', controller: _reviewCtrl),
              const SizedBox(height: 16),
              const _SheetLabel('موعد التسليم'),
              GestureDetector(
                onTap: _pickDueDay,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const Spacer(),
                      Text(
                        _dueDayLabel,
                        style: AppTextStyles.bodyLarge,
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              BlocBuilder<TeacherBloc, TeacherState>(
                buildWhen: (previous, current) =>
                    previous.assignmentSubmissionStatus !=
                    current.assignmentSubmissionStatus,
                builder: (context, state) {
                  final isLoading =
                      state.assignmentSubmissionStatus ==
                      SubmissionStatus.submitting;
                  return AppButton(
                    label: 'إرسال التكليف',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _submit,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppTextStyles.labelLarge,
      textAlign: TextAlign.right,
    ),
  );
}
