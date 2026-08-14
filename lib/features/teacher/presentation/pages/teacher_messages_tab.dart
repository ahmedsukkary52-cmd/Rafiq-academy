import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/domain/policies/chat_permission_policy.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../bloc/teacher_bloc.dart';

/// Teacher Messages inbox — Figma 09 (`1:1314`) Phase 1 UI.
///
/// Filters are presentation-only over existing conversations. Parent tab does
/// **not** enable teacher↔parent messaging ([ChatPermissionPolicy] unchanged).
class TeacherMessagesTab extends StatefulWidget {
  const TeacherMessagesTab({super.key});

  @override
  State<TeacherMessagesTab> createState() => _TeacherMessagesTabState();
}

enum _InboxFilter { all, parents, supervisors, admin }

class _TeacherMessagesTabState extends State<TeacherMessagesTab> {
  final _searchCtrl = TextEditingController();
  _InboxFilter _filter = _InboxFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      sl<ChatConversationsBloc>().add(
        StartWatchingConversationsEvent(authState.user.uid),
      );
    }
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q == _query) return;
      setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _retry() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    sl<ChatConversationsBloc>().add(
      StartWatchingConversationsEvent(authState.user.uid),
    );
  }

  Future<void> _openNewChatPicker(BuildContext context) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    final selected = await showModalBottomSheet<ChatParticipantEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NewChatPickerSheet(
        teacherUid: auth.user.uid,
        teacherRole: auth.user.role,
        halaqat: context.read<TeacherBloc>().state.halaqat,
      ),
    );
    if (selected == null || !mounted) return;

    final currentUser = ChatParticipantEntity(
      uid: auth.user.uid,
      name: auth.user.name,
      role: auth.user.role,
      profileImageUrl: auth.user.profileImageUrl,
    );

    final chatBloc = sl<ChatConversationsBloc>();
    chatBloc.add(const ResetStartConversationEvent());
    chatBloc.add(
      StartConversationEvent(currentUser: currentUser, otherUser: selected),
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
        this.context,
        startState.startConversationError ?? 'تعذر فتح المحادثة',
      );
      chatBloc.add(const ResetStartConversationEvent());
      return;
    }

    final conversation = startState.startedConversation!;
    chatBloc.add(const ResetStartConversationEvent());
    if (!mounted) return;
    this.context.push(
      AppRoutes.teacherChat.replaceFirst(':conversationId', conversation.id),
      extra: <String, String?>{
        'name': selected.name,
        'image': selected.profileImageUrl,
      },
    );
  }

  List<ConversationEntity> _visible(
    List<ConversationEntity> all,
    String currentUid,
  ) {
    Iterable<ConversationEntity> list = all;
    list = list.where((c) {
      final role = c.otherParticipant(currentUid).role;
      return switch (_filter) {
        _InboxFilter.all => true,
        _InboxFilter.parents => role == AppRoles.parent,
        _InboxFilter.supervisors => role == AppRoles.supervisor,
        _InboxFilter.admin => role == AppRoles.admin,
      };
    });
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((c) {
        final other = c.otherParticipant(currentUid);
        final hay = '${other.name} ${c.lastMessage ?? ''}'.toLowerCase();
        return hay.contains(q);
      });
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FAFB),
        body: Column(
          children: [
            _MessagesHeader(
              topPadding: top,
              onNewTap: () => _openNewChatPicker(context),
            ),
            _FilterTabs(
              selected: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _SearchField(controller: _searchCtrl),
            ),
            Expanded(
              child: BlocBuilder<ChatConversationsBloc, ChatConversationsState>(
                bloc: sl<ChatConversationsBloc>(),
                buildWhen: (p, c) =>
                    p.conversationsStatus != c.conversationsStatus ||
                    p.conversations != c.conversations ||
                    p.conversationsError != c.conversationsError,
                builder: (context, state) {
                  final authState = context.read<AuthBloc>().state;
                  final currentUid = authState is AuthAuthenticated
                      ? authState.user.uid
                      : '';

                  if (state.conversationsStatus == SectionStatus.loading ||
                      state.conversationsStatus == SectionStatus.initial) {
                    return const _MessagesListSkeleton();
                  }

                  if (state.conversationsStatus == SectionStatus.error) {
                    return AppErrorWidget(
                      message: state.conversationsError ?? 'تعذر تحميل الرسائل',
                      onRetry: _retry,
                    );
                  }

                  final items = _visible(state.conversations, currentUid);

                  if (state.conversations.isEmpty) {
                    return const _EmptyInbox(
                      title: 'لا توجد رسائل بعد',
                      subtitle: 'ستظهر محادثاتك هنا عند بدء التواصل',
                    );
                  }

                  if (items.isEmpty) {
                    return _EmptyInbox(
                      title: _filter == _InboxFilter.parents
                          ? 'لا محادثات مع أولياء الأمور'
                          : 'لا نتائج',
                      subtitle: _filter == _InboxFilter.parents
                          ? 'التواصل مع ولي الأمر غير متاح في هذه المرحلة'
                          : 'جرّب بحثاً أو تصنيفاً آخر',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 0.8,
                      color: Color(0xFFE8EEF0),
                      indent: 78,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, i) {
                      final conv = items[i];
                      final other = conv.otherParticipant(currentUid);
                      return _ConversationTile(
                        name: other.name,
                        roleLabel: _roleLabel(other.role),
                        snippet: conv.lastMessage ?? '',
                        timeLabel: conv.lastMessageAt == null
                            ? ''
                            : _timeAgo(conv.lastMessageAt!),
                        unread: conv.unreadCount,
                        imageUrl: other.profileImageUrl,
                        highlighted: i == 0 && conv.unreadCount > 0,
                        onTap: () => context.push(
                          AppRoutes.teacherChat.replaceFirst(
                            ':conversationId',
                            conv.id,
                          ),
                          extra: <String, String?>{
                            'name': other.name,
                            'image': other.profileImageUrl,
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(String role) => switch (role) {
    AppRoles.student => 'طالب',
    AppRoles.parent => 'ولي أمر',
    AppRoles.supervisor => 'مشرف',
    AppRoles.admin => 'إدارة',
    AppRoles.teacher => 'معلم',
    _ => role,
  };

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دق';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${dt.day}/${dt.month}';
  }
}

// ── Header / tabs / search ────────────────────────────────────────────────────

class _MessagesHeader extends StatelessWidget {
  final double topPadding;
  final VoidCallback onNewTap;

  const _MessagesHeader({required this.topPadding, required this.onNewTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 12),
      child: Row(
        children: [
          _HeaderIconButton(icon: Icons.add_rounded, onTap: onNewTap),
          Expanded(
            child: Text(
              'الرسائل',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          // Visual balance with Figma back affordance (tab has no stack pop).
          const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5FAFB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final _InboxFilter selected;
  final ValueChanged<_InboxFilter> onChanged;

  const _FilterTabs({required this.selected, required this.onChanged});

  static const _items = [
    (_InboxFilter.all, 'الكل'),
    (_InboxFilter.parents, 'أولياء الأمور'),
    (_InboxFilter.supervisors, 'المشرفون'),
    (_InboxFilter.admin, 'الإدارة'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.only(bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (final (filter, label) in _items)
              _FilterChip(
                label: label,
                selected: selected == filter,
                onTap: () => onChanged(filter),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? AppColors.primaryDark : AppColors.textHint,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2.5,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textPrimary,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        hintText: 'بحث في المحادثات...',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textHint,
          fontSize: 13,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textHint,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          borderSide: const BorderSide(color: Color(0xFFE8EEF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          borderSide: const BorderSide(color: Color(0xFFE8EEF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }
}

// ── Tiles ─────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final String name;
  final String roleLabel;
  final String snippet;
  final String timeLabel;
  final int unread;
  final String? imageUrl;
  final bool highlighted;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.roleLabel,
    required this.snippet,
    required this.timeLabel,
    required this.unread,
    required this.imageUrl,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? AppColors.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LetterAvatar(name: name, imageUrl: imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$name — $roleLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: unread > 0
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (timeLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        timeLabel,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 10),
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LetterAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _LetterAvatar({required this.name, required this.imageUrl});

  static const _palette = [
    Color(0xFFFEF3C7),
    Color(0xFFFFEDD5),
    Color(0xFFEDE9FE),
    Color(0xFFCFFAFE),
    Color(0xFFD1FAE5),
  ];
  static const _fg = [
    Color(0xFF92400E),
    Color(0xFF9A3412),
    Color(0xFF5B21B6),
    Color(0xFF0E7490),
    Color(0xFF065F46),
  ];

  @override
  Widget build(BuildContext context) {
    final i = name.isEmpty ? 0 : name.codeUnits.first % _palette.length;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0];
    final url = imageUrl?.trim();

    return CircleAvatar(
      radius: 24,
      backgroundColor: _palette[i],
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Text(
              initial,
              style: AppTextStyles.titleLarge.copyWith(
                color: _fg[i],
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            )
          : null,
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyInbox({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: AppColors.textHint.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesListSkeleton extends StatefulWidget {
  const _MessagesListSkeleton();

  @override
  State<_MessagesListSkeleton> createState() => _MessagesListSkeletonState();
}

class _MessagesListSkeletonState extends State<_MessagesListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.35,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final bone = AppColors.border.withValues(alpha: _pulse.value);
        Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: bone,
            borderRadius: BorderRadius.circular(6),
          ),
        );
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(radius: 24, backgroundColor: bone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      bar(140, 12),
                      const SizedBox(height: 8),
                      bar(200, 10),
                      const SizedBox(height: 8),
                      bar(64, 9),
                    ],
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

/// Policy-filtered contacts for teacher `+` (students + supervisors of halaqat).
/// Parents are never listed — [ChatPermissionPolicy] rejects teacher↔parent.
class _NewChatPickerSheet extends StatefulWidget {
  final String teacherUid;
  final String teacherRole;
  final List<HalaqaEntity> halaqat;

  const _NewChatPickerSheet({
    required this.teacherUid,
    required this.teacherRole,
    required this.halaqat,
  });

  @override
  State<_NewChatPickerSheet> createState() => _NewChatPickerSheetState();
}

class _NewChatPickerSheetState extends State<_NewChatPickerSheet> {
  bool _loading = true;
  String? _error;
  List<ChatParticipantEntity> _contacts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final uids = <String>{};
    for (final h in widget.halaqat) {
      uids.addAll(h.studentIds);
      if (h.supervisorId.trim().isNotEmpty) {
        uids.add(h.supervisorId.trim());
      }
    }
    uids.remove(widget.teacherUid);

    if (uids.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _contacts = const [];
      });
      return;
    }

    final getParticipant = sl<GetChatParticipantUseCase>();
    final results = await Future.wait(
      uids.map((uid) => getParticipant(ChatUidParams(uid))),
    );

    final contacts = <ChatParticipantEntity>[];
    for (final either in results) {
      either.fold((_) {}, (p) {
        if (ChatPermissionPolicy.canChat(widget.teacherRole, p.role)) {
          contacts.add(p);
        }
      });
    }
    contacts.sort((a, b) {
      final roleCmp = a.role.compareTo(b.role);
      if (roleCmp != 0) return roleCmp;
      return a.name.compareTo(b.name);
    });

    if (!mounted) return;
    setState(() {
      _loading = false;
      _contacts = contacts;
      if (contacts.isEmpty && uids.isNotEmpty) {
        _error = null;
      }
    });
  }

  String _roleLabel(String role) => switch (role) {
    AppRoles.student => 'طالب',
    AppRoles.supervisor => 'مشرف',
    AppRoles.admin => 'إدارة',
    _ => role,
  };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'محادثة جديدة',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const _NewChatPickerSkeleton()
                    : _contacts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error ??
                                'لا يوجد طلاب أو مشرفون متاحون للمحادثة من حلقاتك',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(8, 4, 8, bottom + 16),
                        itemCount: _contacts.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) {
                          final p = _contacts[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              backgroundImage:
                                  p.profileImageUrl != null &&
                                      p.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(p.profileImageUrl!)
                                  : null,
                              child:
                                  p.profileImageUrl == null ||
                                      p.profileImageUrl!.isEmpty
                                  ? Text(
                                      p.name.isNotEmpty ? p.name[0] : '?',
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              p.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              _roleLabel(p.role),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(p),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewChatPickerSkeleton extends StatefulWidget {
  const _NewChatPickerSkeleton();

  @override
  State<_NewChatPickerSkeleton> createState() => _NewChatPickerSkeletonState();
}

class _NewChatPickerSkeletonState extends State<_NewChatPickerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.35,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final bone = AppColors.border.withValues(alpha: _pulse.value);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 5,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(radius: 22, backgroundColor: bone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                          color: bone,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 64,
                        height: 10,
                        decoration: BoxDecoration(
                          color: bone,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
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
