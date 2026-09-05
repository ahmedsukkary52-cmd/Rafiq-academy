import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/parent_household.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../bloc/parent_state.dart';
import '../parent_destinations.dart';
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';
import '../widgets/parent_user_avatar.dart';

class ParentChildrenPage extends StatefulWidget {
  const ParentChildrenPage({super.key});

  @override
  State<ParentChildrenPage> createState() => _ParentChildrenPageState();
}

class _ParentChildrenPageState extends State<ParentChildrenPage> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';
  bool _startingChat = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<ParentBloc>().add(LoadChildrenEvent(auth.user.uid));
  }

  Future<void> _startSupervisorChat(ParentChildSnapshot child) async {
    final auth = context.read<AuthBloc>().state;
    final supervisorId = (child.supervisorId ?? '').trim();
    if (auth is! AuthAuthenticated || _startingChat) return;
    if (supervisorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مشرف مرتبط بهذا الابن')),
      );
      return;
    }

    final staff = context.read<ParentBloc>().state.staffContacts;
    ParentStaffContact? contact;
    for (final item in staff) {
      if (item.uid == supervisorId) {
        contact = item;
        break;
      }
    }
    contact ??= ParentStaffContact(
      uid: supervisorId,
      name: child.supervisorName.trim().isEmpty
          ? 'المشرف'
          : child.supervisorName.trim(),
      role: AppRoles.supervisor,
    );

    setState(() => _startingChat = true);
    final conversations = sl<ChatConversationsBloc>().state.conversations;
    for (final conversation in conversations) {
      final other = conversation.otherParticipant(auth.user.uid);
      if (other.uid == contact.uid) {
        setState(() => _startingChat = false);
        if (!mounted) return;
        await ParentDestinations.chat(
          context,
          conversationId: conversation.id,
          title: other.name.trim().isEmpty ? contact.name : other.name,
          imageUrl: other.profileImageUrl ?? contact.profileImageUrl,
        );
        return;
      }
    }

    sl<ChatConversationsBloc>().add(const ResetStartConversationEvent());
    sl<ChatConversationsBloc>().add(
      StartConversationEvent(
        currentUser: ChatParticipantEntity(
          uid: auth.user.uid,
          name: auth.user.name,
          role: AppRoles.parent,
          profileImageUrl: auth.user.profileImageUrl,
        ),
        otherUser: ChatParticipantEntity(
          uid: contact.uid,
          name: contact.name,
          role: contact.role,
          profileImageUrl: contact.profileImageUrl,
        ),
      ),
    );
  }

  bool _matches(ParentChildSnapshot? snap, String name) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    final haystack = [
      name,
      snap?.halaqaName ?? '',
      snap?.teacherName ?? '',
    ].join(' ');
    return haystack.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocListener<ChatConversationsBloc, ChatConversationsState>(
        bloc: sl<ChatConversationsBloc>(),
        listenWhen: (p, c) =>
            p.startConversationStatus != c.startConversationStatus,
        listener: (context, state) async {
          if (!_startingChat) return;
          if (state.startConversationStatus == SubmissionStatus.error) {
            setState(() => _startingChat = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.startConversationError ?? 'تعذر بدء المحادثة',
                ),
              ),
            );
            return;
          }
          if (state.startConversationStatus == SubmissionStatus.success &&
              state.startedConversation != null) {
            final conversation = state.startedConversation!;
            sl<ChatConversationsBloc>().add(
              const ResetStartConversationEvent(),
            );
            setState(() => _startingChat = false);
            final other = conversation.otherParticipant(uid);
            if (!mounted) return;
            await ParentDestinations.chat(
              context,
              conversationId: conversation.id,
              title: other.name,
              imageUrl: other.profileImageUrl,
            );
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: _searching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'بحث عن ابن أو حلقة...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.dark,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.onPrimary,
                    ),
                    cursorColor: AppColors.onPrimary,
                    onChanged: (value) => setState(() => _query = value),
                  )
                : const Text('أبنائي'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                tooltip: _searching ? 'إغلاق البحث' : 'بحث',
                onPressed: () {
                  setState(() {
                    _searching = !_searching;
                    if (!_searching) {
                      _query = '';
                      _searchController.clear();
                    }
                  });
                },
                icon: Icon(
                  _searching ? Icons.close_rounded : Icons.search_rounded,
                ),
              ),
            ],
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
                  onRetry: _reload,
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
              final visible =
                  <({String id, String name, ParentChildSnapshot? snap})>[];
              for (final id in state.childrenIds) {
                ParentChildSnapshot? snap;
                for (final item in snapshots) {
                  if (item.studentId == id) {
                    snap = item;
                    break;
                  }
                }
                final name = snap?.displayName ?? state.childDisplayName(id);
                if (_matches(snap, name)) {
                  visible.add((id: id, name: name, snap: snap));
                }
              }

              if (visible.isEmpty) {
                return const ParentEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'لا توجد نتائج',
                  message: 'جرّب اسماً أو حلقة أخرى.',
                );
              }

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => _reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return _ChildStatusCard(
                      studentId: item.id,
                      name: item.name,
                      snapshot: item.snap,
                      onSupervisor: item.snap == null
                          ? null
                          : () => _startSupervisorChat(item.snap!),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChildStatusCard extends StatelessWidget {
  final String studentId;
  final String name;
  final ParentChildSnapshot? snapshot;
  final VoidCallback? onSupervisor;

  const _ChildStatusCard({
    required this.studentId,
    required this.name,
    this.snapshot,
    this.onSupervisor,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = snapshot?.paymentStatus == PaymentStatus.overdue;
    final atRisk = snapshot?.isAtRisk == true;
    final accent = (atRisk || overdue) ? AppColors.error : AppColors.success;
    final percent = snapshot == null
        ? null
        : (snapshot!.overallProgressPercent > 0
              ? snapshot!.overallProgressPercent
              : snapshot!.attendancePercentInWindow);
    final halaqa = snapshot?.halaqaName.trim() ?? '';
    final teacher = parentTeacherCaption(snapshot?.teacherName ?? '');
    final payment = parentPaymentLabel(snapshot?.paymentStatus);
    final attendance = parentAttendanceLabel(snapshot?.todayAttendanceStatus);
    final verses = snapshot?.totalVersesMemorized ?? 0;
    final progress = ((snapshot?.overallProgressPercent ?? 0) / 100)
        .clamp(0.0, 1.0)
        .toDouble();
    final hasSupervisor =
        (snapshot?.supervisorId ?? '').trim().isNotEmpty &&
        onSupervisor != null;
    // Escalation CTA — only when the child actually needs follow-up.
    final showSupervisorContact = hasSupervisor && atRisk;
    final banner = snapshot == null ? null : parentChildStatusBanner(snapshot!);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.softShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ParentUserAvatar(
                            name: name,
                            imageUrl: snapshot?.profileImageUrl,
                            radius: 26,
                            backgroundColor: atRisk
                                ? const Color(0xFFFFE8EE)
                                : AppColors.secondaryBg,
                            foregroundColor: atRisk
                                ? AppColors.error
                                : AppColors.secondaryDeep,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.headlineMedium.copyWith(
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _MetaLine(
                                  icon: Icons.folder_outlined,
                                  text: halaqa.isEmpty
                                      ? 'لم تُحدد حلقة بعد'
                                      : halaqa,
                                ),
                                if (teacher.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  _MetaLine(
                                    icon: Icons.person_outline_rounded,
                                    text: teacher,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Text(
                                parentPercentLabel(percent),
                                style: AppTextStyles.displayMedium.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'إجمالي',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textHint,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (payment.isNotEmpty)
                            _StatusChip(
                              label: payment,
                              color:
                                  snapshot?.paymentStatus == PaymentStatus.paid
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          _StatusChip(
                            label: attendance,
                            color: switch ((snapshot?.todayAttendanceStatus ??
                                    '')
                                .trim()) {
                              AttendancePolicy.statusPresent =>
                                AppColors.success,
                              AttendancePolicy.statusAbsent => AppColors.error,
                              AttendancePolicy.statusLate => AppColors.warning,
                              _ => AppColors.info,
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تقدم الحفظ',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${parentEasternDigits('$verses')} آية محفوظة',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          color: AppColors.secondary,
                        ),
                      ),
                      if (banner != null) ...[
                        const SizedBox(height: 12),
                        _BannerStrip(text: banner, warning: atRisk),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => ParentDestinations.childProfile(
                                context,
                                studentId: studentId,
                                studentName: name,
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: AppColors.primaryGradientMid,
                                minimumSize: const Size(0, 42),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('الملف الشخصي'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => ParentDestinations.reports(
                                context,
                                studentId: studentId,
                                studentName: name,
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                backgroundColor: AppColors.primaryGradientStart
                                    .withValues(alpha: 0.07),
                                minimumSize: const Size(0, 42),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(
                                'التقارير',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (overdue || showSupervisorContact) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (overdue)
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      ParentDestinations.subscriptions(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: AppColors.textPrimary,
                                    minimumSize: const Size(0, 42),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('سداد'),
                                ),
                              ),
                            if (overdue && showSupervisorContact)
                              const SizedBox(width: 8),
                            if (showSupervisorContact)
                              Expanded(
                                flex: overdue ? 2 : 1,
                                child: OutlinedButton(
                                  onPressed: onSupervisor,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(
                                      color: AppColors.error,
                                    ),
                                    backgroundColor: const Color(0xFFFDEAEA),
                                    minimumSize: const Size(0, 42),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('تواصل مع المشرف'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _BannerStrip extends StatelessWidget {
  final String text;
  final bool warning;

  const _BannerStrip({required this.text, required this.warning});

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.error : AppColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Row(
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.star_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
