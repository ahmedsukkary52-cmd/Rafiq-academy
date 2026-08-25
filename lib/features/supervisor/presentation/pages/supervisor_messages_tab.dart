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
import '../../../chat/domain/policies/chat_permission_policy.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../chat/presentation/pages/chat_room.dart';
import '../../../parent/domain/repositories/parent_repositories.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';

/// Supervisor inbox — teachers / parents / admin only (no students, no groups).
class SupervisorMessagesTab extends StatefulWidget {
  const SupervisorMessagesTab({super.key});

  @override
  State<SupervisorMessagesTab> createState() => _SupervisorMessagesTabState();
}

enum _InboxFilter { all, teachers, parents, admin }

class _SupervisorMessagesTabState extends State<SupervisorMessagesTab> {
  final _searchCtrl = TextEditingController();
  _InboxFilter _filter = _InboxFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      sl<ChatConversationsBloc>().add(
        StartWatchingConversationsEvent(auth.user.uid),
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
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    sl<ChatConversationsBloc>().add(
      StartWatchingConversationsEvent(auth.user.uid),
    );
  }

  Future<void> _openRoom(
    BuildContext context, {
    required String conversationId,
    required String name,
    String? imageUrl,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomPage(
          conversationId: conversationId,
          otherUserName: name,
          otherUserImage: imageUrl,
        ),
      ),
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
        supervisorUid: auth.user.uid,
        supervisorRole: auth.user.role,
        halaqat: context.read<SupervisorBloc>().state.halaqat,
        conversations: sl<ChatConversationsBloc>().state.conversations,
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
    await _openRoom(
      this.context,
      conversationId: conversation.id,
      name: selected.name,
      imageUrl: selected.profileImageUrl,
    );
  }

  List<ConversationEntity> _visible(
    List<ConversationEntity> all,
    String currentUid,
  ) {
    Iterable<ConversationEntity> list = all.where((c) {
      final role = c.otherParticipant(currentUid).role;
      // Supervisor inbox never lists students.
      if (role == AppRoles.student) return false;
      return switch (_filter) {
        _InboxFilter.all =>
          role == AppRoles.teacher ||
              role == AppRoles.parent ||
              role == AppRoles.admin,
        _InboxFilter.teachers => role == AppRoles.teacher,
        _InboxFilter.parents => role == AppRoles.parent,
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
        backgroundColor: AppColors.background,
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
              child: TextField(
                controller: _searchCtrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'بحث في المحادثات...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
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
                  final uid = authState is AuthAuthenticated
                      ? authState.user.uid
                      : '';

                  if (state.conversationsStatus == SectionStatus.loading ||
                      state.conversationsStatus == SectionStatus.initial) {
                    return const Center(child: AppLoadingWidget());
                  }

                  if (state.conversationsStatus == SectionStatus.error) {
                    return AppErrorWidget(
                      message: state.conversationsError ?? 'تعذر تحميل الرسائل',
                      onRetry: _retry,
                    );
                  }

                  final items = _visible(state.conversations, uid);

                  if (state.conversations.isEmpty) {
                    return Center(
                      child: Text(
                        'لا توجد رسائل بعد',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }

                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'لا نتائج',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 78, endIndent: 16),
                    itemBuilder: (context, i) {
                      final conv = items[i];
                      final other = conv.otherParticipant(uid);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage:
                              other.profileImageUrl != null &&
                                  other.profileImageUrl!.isNotEmpty
                              ? NetworkImage(other.profileImageUrl!)
                              : null,
                          child:
                              other.profileImageUrl == null ||
                                  other.profileImageUrl!.isEmpty
                              ? Text(
                                  other.name.isNotEmpty ? other.name[0] : '؟',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          '${other.name} — ${_roleLabel(other.role)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: conv.unreadCount > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          conv.lastMessage ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: conv.unreadCount > 0
                            ? CircleAvatar(
                                radius: 11,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  conv.unreadCount > 9
                                      ? '9+'
                                      : '${conv.unreadCount}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.onPrimary,
                                    fontSize: 10,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => _openRoom(
                          context,
                          conversationId: conv.id,
                          name: other.name,
                          imageUrl: other.profileImageUrl,
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
    AppRoles.parent => 'ولي أمر',
    AppRoles.admin => 'إدارة',
    AppRoles.teacher => 'معلم',
    AppRoles.supervisor => 'مشرف',
    _ => role,
  };
}

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
          Material(
            color: AppColors.surfaceGrey,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onNewTap,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.add_rounded, size: 22),
              ),
            ),
          ),
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
          const SizedBox(width: 40, height: 40),
        ],
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
    (_InboxFilter.teachers, 'المعلمون'),
    (_InboxFilter.parents, 'أولياء الأمور'),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected == filter,
                  onSelected: (_) => onChanged(filter),
                  selectedColor: AppColors.primaryLight,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewChatPickerSheet extends StatefulWidget {
  final String supervisorUid;
  final String supervisorRole;
  final List<HalaqaEntity> halaqat;
  final List<ConversationEntity> conversations;

  const _NewChatPickerSheet({
    required this.supervisorUid,
    required this.supervisorRole,
    required this.halaqat,
    required this.conversations,
  });

  @override
  State<_NewChatPickerSheet> createState() => _NewChatPickerSheetState();
}

class _NewChatPickerSheetState extends State<_NewChatPickerSheet> {
  bool _loading = true;
  List<ChatParticipantEntity> _contacts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final uids = <String>{};

    // Teachers of assigned halaqat.
    for (final h in widget.halaqat) {
      final tid = h.teacherId.trim();
      if (tid.isNotEmpty) uids.add(tid);
    }

    // Existing conversation peers (teacher/parent/admin only).
    for (final c in widget.conversations) {
      final other = c.otherParticipant(widget.supervisorUid);
      if (ChatPermissionPolicy.canChat(widget.supervisorRole, other.role) &&
          other.role != AppRoles.student) {
        uids.add(other.uid);
      }
    }

    // Parents linked to roster students.
    final studentIds = SupervisorRoster.uniqueStudentIds(widget.halaqat);
    if (studentIds.isNotEmpty) {
      final parentsResult = await sl<ParentRepository>()
          .getParentIdsByStudentIds(studentIds);
      parentsResult.fold((_) {}, (map) {
        for (final ids in map.values) {
          uids.addAll(ids.where((id) => id.trim().isNotEmpty));
        }
      });
    }

    uids.remove(widget.supervisorUid);

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
    final seen = <String>{};
    for (final either in results) {
      either.fold((_) {}, (p) {
        if (!seen.add(p.uid)) return;
        if (!ChatPermissionPolicy.canChat(widget.supervisorRole, p.role)) {
          return;
        }
        if (p.role == AppRoles.student) return;
        contacts.add(p);
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
    });
  }

  String _roleLabel(String role) => switch (role) {
    AppRoles.parent => 'ولي أمر',
    AppRoles.admin => 'إدارة',
    AppRoles.teacher => 'معلم',
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
                    ? const Center(child: AppLoadingWidget())
                    : _contacts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'لا يوجد معلمون أو أولياء أمور متاحون من حلقاتك',
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
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage:
                                  p.profileImageUrl != null &&
                                      p.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(p.profileImageUrl!)
                                  : null,
                              child:
                                  p.profileImageUrl == null ||
                                      p.profileImageUrl!.isEmpty
                                  ? Text(
                                      p.name.isNotEmpty ? p.name[0] : '؟',
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: AppColors.primaryDark,
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
                            subtitle: Text(_roleLabel(p.role)),
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
