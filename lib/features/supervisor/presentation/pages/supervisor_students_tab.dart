import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/pages/chat_room.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../parent/domain/parent_payment_proof.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/repositories/parent_repository.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../supervisor_destinations.dart';
import '../supervisor_home_nav.dart';
import '../widgets/supervisor_loading_skeletons.dart';

String _eastern(String input) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final code in input.runes) {
    final ch = String.fromCharCode(code);
    final i = western.indexOf(ch);
    buffer.write(i >= 0 ? eastern[i] : ch);
  }
  return buffer.toString();
}

enum _ChipFilter { all, outstanding, atRisk, absences, dual, paymentDue }

class SupervisorStudentsTab extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const SupervisorStudentsTab({super.key, this.onSwitchTab});

  @override
  State<SupervisorStudentsTab> createState() => _SupervisorStudentsTabState();
}

class _SupervisorStudentsTabState extends State<SupervisorStudentsTab> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  _ChipFilter _chip = _ChipFilter.all;
  String _query = '';
  String? _halaqaFilterId;
  String? _teacherFilterId;
  int? _levelFilter;

  List<SupervisorStudentRow> _rows = const [];
  List<HalaqaEntity> _halaqat = const [];
  bool _loading = false;
  String? _error;
  int _loadGen = 0;
  String _halaqaKey = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q == _query) return;
      setState(() => _query = q);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncFromBloc(context.read<SupervisorBloc>().state);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _reloadHalaqat() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<SupervisorBloc>().add(
      LoadSupervisedHalaqatEvent(auth.user.uid),
    );
  }

  void _syncFromBloc(SupervisorState state) {
    _halaqat = state.halaqat;
    if (state.halaqatStatus == SectionStatus.initial ||
        state.halaqatStatus == SectionStatus.loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
      return;
    }
    if (state.halaqatStatus == SectionStatus.error) {
      setState(() {
        _loading = false;
        _error = state.halaqatError ?? 'تعذر تحميل الحلقات';
        _rows = const [];
      });
      return;
    }

    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated &&
        state.paymentsStatus == SectionStatus.initial) {
      final studentIds = <String>{
        for (final h in state.halaqat) ...h.studentIds,
      }.toList();
      context.read<SupervisorBloc>().add(
        LoadSupervisedPaymentsEvent(
          supervisorId: auth.user.uid,
          studentIds: studentIds,
        ),
      );
    }

    final key = state.halaqat.map((h) => h.id).join('|');
    if (key == _halaqaKey && _rows.isNotEmpty) return;
    _halaqaKey = key;
    _loadSummaries(state);
  }

  Future<void> _loadSummaries(SupervisorState state) async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
      _halaqat = state.halaqat;
    });

    if (state.halaqat.isEmpty) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _rows = const [];
        _loading = false;
      });
      return;
    }

    final byHalaqa = <String, List<HalaqaStudentSummaryEntity>>{};
    final getStudents = sl<GetHalaqaStudentsUseCase>();
    String? firstError;

    await Future.wait(
      state.halaqat.map((h) async {
        final result = await getStudents(HalaqaStudentsParams(h.id));
        result.fold(
          (f) => firstError ??= f.message,
          (list) => byHalaqa[h.id] = list,
        );
      }),
    );

    if (!mounted || gen != _loadGen) return;

    if (byHalaqa.isEmpty && firstError != null) {
      setState(() {
        _loading = false;
        _error = firstError;
        _rows = const [];
      });
      return;
    }

    final teacherIds = <String>{
      for (final h in state.halaqat)
        if (h.teacherId.trim().isNotEmpty) h.teacherId.trim(),
    };
    final namesResult = await sl<SupervisorRepository>().getUserDisplayNames(
      teacherIds.toList(),
    );
    final teacherNames = namesResult.getOrElse((_) => const <String, String>{});

    if (!mounted || gen != _loadGen) return;

    setState(() {
      _rows = SupervisorRoster.mergeSummaries(
        halaqat: state.halaqat,
        byHalaqaId: byHalaqa,
        teacherNamesById: teacherNames,
      );
      _loading = false;
      _error = null;
    });
  }

  List<SupervisorStudentRow> get _visible {
    Iterable<SupervisorStudentRow> list = _rows;

    list = switch (_chip) {
      _ChipFilter.all => list,
      _ChipFilter.outstanding => list.where((r) => r.isOutstanding),
      _ChipFilter.atRisk => list.where((r) => r.isAtRisk),
      _ChipFilter.absences => list.where((r) => r.hasAttendanceConcern),
      _ChipFilter.dual => list.where((r) => r.isDualMember),
      _ChipFilter.paymentDue => list.where((r) {
        final payments = context.read<SupervisorBloc>().state.payments;
        return payments.any(
          (p) =>
              p.studentId == r.studentId &&
              (p.status == PaymentStatus.due ||
                  p.status == PaymentStatus.overdue ||
                  p.hasProofAwaitingReview),
        );
      }),
    };

    final halaqaId = _halaqaFilterId;
    if (halaqaId != null) {
      list = list.where((r) => r.halaqaIds.contains(halaqaId));
    }
    final teacherId = _teacherFilterId;
    if (teacherId != null) {
      list = list.where((r) => r.teacherIds.contains(teacherId));
    }
    final level = _levelFilter;
    if (level != null) {
      list = list.where((r) => r.level == level);
    }

    if (_query.isNotEmpty) {
      final tokens = _query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty);
      list = list.where((r) {
        final hay = r.searchBlob;
        return tokens.every(hay.contains);
      });
    }

    return list.toList();
  }

  Set<int> get _levels {
    return {for (final r in _rows) r.level}..removeWhere((l) => l <= 0);
  }

  Map<String, String> get _teachers {
    final map = <String, String>{};
    for (final r in _rows) {
      for (var i = 0; i < r.teacherIds.length; i++) {
        final id = r.teacherIds[i];
        if (id.isEmpty || map.containsKey(id)) continue;
        final name = i < r.teacherNames.length ? r.teacherNames[i].trim() : '';
        map[id] = name.isEmpty ? id : name;
      }
    }
    return map;
  }

  Future<void> _messageTeacher(SupervisorStudentRow row) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }
    final teacherId = row.teacherIds.isNotEmpty ? row.teacherIds.first : '';
    if (teacherId.isEmpty) {
      AppSnackBar.showInfo(context, 'لا يوجد معلم مرتبط بهذا الطالب');
      return;
    }

    final participant = await sl<GetChatParticipantUseCase>()(
      ChatUidParams(teacherId),
    );
    final other = participant.fold<ChatParticipantEntity?>(
      (_) => null,
      (p) => p,
    );
    if (other == null) {
      if (!mounted) return;
      AppSnackBar.showInfo(context, 'تعذر تحميل بيانات المعلم');
      return;
    }

    final chatBloc = sl<ChatConversationsBloc>();
    chatBloc.add(const ResetStartConversationEvent());
    chatBloc.add(
      StartConversationEvent(
        currentUser: ChatParticipantEntity(
          uid: auth.user.uid,
          name: auth.user.name,
          role: AppRoles.supervisor,
          profileImageUrl: auth.user.profileImageUrl,
        ),
        otherUser: other,
      ),
    );

    final startState = await chatBloc.stream.firstWhere(
      (s) =>
          s.startConversationStatus == SubmissionStatus.success ||
          s.startConversationStatus == SubmissionStatus.error,
    );
    if (!mounted) return;

    if (startState.startConversationStatus == SubmissionStatus.error ||
        startState.startedConversation == null) {
      AppSnackBar.showInfo(
        context,
        startState.startConversationError ?? 'تعذر فتح المحادثة',
      );
      chatBloc.add(const ResetStartConversationEvent());
      return;
    }

    final conversation = startState.startedConversation!;
    chatBloc.add(const ResetStartConversationEvent());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomPage(
          conversationId: conversation.id,
          otherUserName: other.name,
          otherUserImage: other.profileImageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final visible = _visible;
    final teachers = _teachers;

    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) =>
          p.halaqatStatus != c.halaqatStatus ||
          p.halaqat != c.halaqat ||
          p.payments != c.payments,
      listener: (context, state) {
        _syncFromBloc(state);
        if (mounted) setState(() {});
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          floatingActionButton: FloatingActionButton(
            onPressed: () => SupervisorDestinations.register(context),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            child: const Icon(Icons.add_rounded),
          ),
          body: Column(
            children: [
              _TopBar(
                top: top,
                onSearchFocus: () => _searchFocus.requestFocus(),
                onFilterHint: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('استخدم الفلاتر أسفل البحث')),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: _SearchField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  showClear: _query.isNotEmpty,
                  onClear: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
              ),
              _ChipRow(
                selected: _chip,
                total: _rows.length,
                onChanged: (v) => setState(() => _chip = v),
              ),
              const SizedBox(height: 8),
              _DropdownFilters(
                halaqat: _halaqat,
                teachers: teachers,
                levels: _levels.toList()..sort(),
                halaqaId: _halaqaFilterId,
                teacherId: _teacherFilterId,
                level: _levelFilter,
                onHalaqa: (id) => setState(() => _halaqaFilterId = id),
                onTeacher: (id) => setState(() => _teacherFilterId = id),
                onLevel: (level) => setState(() => _levelFilter = level),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(visible)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<SupervisorStudentRow> items) {
    if (_loading) {
      return const SupervisorCenteredListSkeleton();
    }
    if (_error != null) {
      return AppErrorWidget(
        message: _error!,
        onRetry: () {
          final state = context.read<SupervisorBloc>().state;
          if (state.halaqatStatus == SectionStatus.error) {
            _reloadHalaqat();
          } else {
            _halaqaKey = '';
            _loadSummaries(state);
          }
        },
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school_outlined,
                size: 44,
                color: AppColors.textHint.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 12),
              Text(
                'لا يوجد طلاب في حلقاتك بعد',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'سجّل طالبًا أو انتظر تعيين حلقات تحت إشرافك',
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
    if (items.isEmpty) {
      return Center(
        child: Text(
          'لا نتائج مطابقة للبحث أو الفلاتر',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        _halaqaKey = '';
        await _loadSummaries(context.read<SupervisorBloc>().state);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final row = items[i];
          final halaqaId = row.halaqaIds.isNotEmpty
              ? row.halaqaIds.first
              : null;
          return _StudentCard(
            row: row,
            onProfile: () => SupervisorDestinations.studentProfile(
              context,
              studentId: row.studentId,
              halaqaId: halaqaId,
            ),
            onMessage: () => _messageTeacher(row),
            onAward: () => SupervisorDestinations.grantAward(
              context,
              preselectedStudentId: row.studentId,
              preselectedHalaqaId: halaqaId,
            ),
            onContactParents: () {
              widget.onSwitchTab?.call(SupervisorHomeNav.messagesIndex);
              if (widget.onSwitchTab == null) {
                AppSnackBar.showInfo(context, 'افتح تبويب الرسائل للتواصل');
              }
            },
            onWarn: () => SupervisorDestinations.followUp(context),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final double top;
  final VoidCallback onSearchFocus;
  final VoidCallback onFilterHint;

  const _TopBar({
    required this.top,
    required this.onSearchFocus,
    required this.onFilterHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 10),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.arrow_forward_ios_rounded,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('أنت في تبويب الطلاب')),
            ),
          ),
          Expanded(
            child: Text(
              'قاعدة بيانات الطلاب',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          _RoundIconButton(icon: Icons.search_rounded, onTap: onSearchFocus),
          const SizedBox(width: 8),
          _RoundIconButton(icon: Icons.tune_rounded, onTap: onFilterHint),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceGrey,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showClear;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.showClear,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textAlign: TextAlign.right,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'بحث بالاسم، المعلم، الحلقة...',
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.primaryDark,
        ),
        suffixIcon: showClear
            ? IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final _ChipFilter selected;
  final int total;
  final ValueChanged<_ChipFilter> onChanged;

  const _ChipRow({
    required this.selected,
    required this.total,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <(_ChipFilter, String)>[
      (_ChipFilter.all, 'الكل (${_eastern('$total')})'),
      (_ChipFilter.outstanding, 'متفوقون'),
      (_ChipFilter.atRisk, 'في خطر'),
      (_ChipFilter.absences, 'غيابات'),
      (_ChipFilter.dual, 'مزدوج'),
      (_ChipFilter.paymentDue, 'اشتراك'),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label) = chips[i];
          final active = selected == value;
          return Material(
            color: active ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: InkWell(
              onTap: () => onChanged(value),
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.primary,
                    width: 1.1,
                  ),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: active ? AppColors.onPrimary : AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DropdownFilters extends StatelessWidget {
  final List<HalaqaEntity> halaqat;
  final Map<String, String> teachers;
  final List<int> levels;
  final String? halaqaId;
  final String? teacherId;
  final int? level;
  final ValueChanged<String?> onHalaqa;
  final ValueChanged<String?> onTeacher;
  final ValueChanged<int?> onLevel;

  const _DropdownFilters({
    required this.halaqat,
    required this.teachers,
    required this.levels,
    required this.halaqaId,
    required this.teacherId,
    required this.level,
    required this.onHalaqa,
    required this.onTeacher,
    required this.onLevel,
  });

  Future<void> _pickHalaqa(BuildContext context) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _FilterSheet(
        title: 'اختر الحلقة',
        options: [(null, 'كل الحلقات'), ...halaqat.map((h) => (h.id, h.name))],
        selected: halaqaId,
      ),
    );
    if (picked == '__cancel__') return;
    onHalaqa(picked);
  }

  Future<void> _pickTeacher(BuildContext context) async {
    final entries = teachers.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _FilterSheet(
        title: 'اختر المعلم',
        options: [
          (null, 'كل المعلمين'),
          ...entries.map((e) => (e.key, e.value)),
        ],
        selected: teacherId,
      ),
    );
    if (picked == '__cancel__') return;
    onTeacher(picked);
  }

  Future<void> _pickLevel(BuildContext context) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _FilterSheet(
        title: 'اختر المستوى',
        options: [
          (null, 'كل المستويات'),
          ...levels.map((l) => ('$l', 'المستوى ${_eastern('$l')}')),
        ],
        selected: level?.toString(),
      ),
    );
    if (picked == '__cancel__') return;
    onLevel(picked == null ? null : int.tryParse(picked));
  }

  @override
  Widget build(BuildContext context) {
    String halaqaLabel = 'الحلقة';
    if (halaqaId != null) {
      final match = halaqat.where((h) => h.id == halaqaId);
      if (match.isNotEmpty) halaqaLabel = match.first.name;
    }
    String teacherLabel = 'المعلم';
    if (teacherId != null) {
      teacherLabel = teachers[teacherId!] ?? 'المعلم';
    }
    final levelLabel = level == null
        ? 'المستوى'
        : 'المستوى ${_eastern('$level')}';

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterPill(
            label: halaqaLabel,
            active: halaqaId != null,
            onTap: () => _pickHalaqa(context),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: teacherLabel,
            active: teacherId != null,
            onTap: () => _pickTeacher(context),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: levelLabel,
            active: level != null,
            onTap: () => _pickLevel(context),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primaryLight : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active ? AppColors.primaryDark : AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final String title;
  final List<(String?, String)> options;
  final String? selected;

  const _FilterSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, i) {
                final (id, label) = options[i];
                final active = selected == id;
                return ListTile(
                  title: Text(
                    label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: active
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, '__cancel__'),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }
}

enum _StudentTone { outstanding, atRisk, active }

class _StudentCard extends StatelessWidget {
  final SupervisorStudentRow row;
  final VoidCallback onProfile;
  final VoidCallback onMessage;
  final VoidCallback onAward;
  final VoidCallback onContactParents;
  final VoidCallback onWarn;

  const _StudentCard({
    required this.row,
    required this.onProfile,
    required this.onMessage,
    required this.onAward,
    required this.onContactParents,
    required this.onWarn,
  });

  _StudentTone get _tone {
    if (row.isAtRisk) return _StudentTone.atRisk;
    if (row.isOutstanding) return _StudentTone.outstanding;
    return _StudentTone.active;
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final accent = switch (tone) {
      _StudentTone.outstanding => AppColors.secondary,
      _StudentTone.atRisk => AppColors.error,
      _StudentTone.active => AppColors.primary,
    };
    final badgeBg = switch (tone) {
      _StudentTone.outstanding => AppColors.secondaryBg,
      _StudentTone.atRisk => const Color(0xFFFFE8EE),
      _StudentTone.active => AppColors.primaryLight,
    };
    final badgeLabel = switch (tone) {
      _StudentTone.outstanding => 'متفوق',
      _StudentTone.atRisk => 'في خطر',
      _StudentTone.active => 'نشط',
    };
    final progress = row.overallProgressPercent.clamp(0.0, 100.0);
    final teacher = row.teacherLabel;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      child: InkWell(
        onTap: onProfile,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
            boxShadow: const [
              BoxShadow(
                color: AppColors.softShadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: badgeBg,
                    backgroundImage:
                        row.profileImageUrl != null &&
                            row.profileImageUrl!.isNotEmpty
                        ? NetworkImage(row.profileImageUrl!)
                        : null,
                    child:
                        row.profileImageUrl == null ||
                            row.profileImageUrl!.isEmpty
                        ? Text(
                            row.displayName.isNotEmpty
                                ? row.displayName[0]
                                : '؟',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _MetaChip(
                              icon: Icons.menu_book_rounded,
                              label: row.halaqaLabel,
                            ),
                            if (teacher.isNotEmpty)
                              _MetaChip(
                                icon: Icons.person_outline_rounded,
                                label: teacher,
                              ),
                            if (row.isDualMember)
                              const _MetaChip(
                                icon: Icons.layers_outlined,
                                label: 'مزدوج',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      badgeLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 8,
                        backgroundColor: accent.withValues(alpha: 0.12),
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_eastern('${progress.round()}')}%',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (tone == _StudentTone.atRisk)
                Row(
                  children: [
                    Expanded(
                      child: _OutlineAction(label: 'الملف', onTap: onProfile),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _FilledAction(
                        label: 'تواصل مع الأهل',
                        color: AppColors.warning,
                        onTap: onContactParents,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _FilledAction(
                        label: 'تحذير',
                        color: AppColors.error,
                        onTap: onWarn,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _OutlineAction(label: 'الملف', onTap: onProfile),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _OutlineAction(label: 'رسالة', onTap: onMessage),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _FilledAction(
                        label: 'منح جائزة',
                        color: AppColors.secondary,
                        onTap: onAward,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.55)),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FilledAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FilledAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
