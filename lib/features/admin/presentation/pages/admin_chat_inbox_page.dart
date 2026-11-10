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
import '../../../chat/data/chat_groups_repository.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/domain/policies/chat_permission_policy.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../chat/presentation/chat_groups_provider.dart';
import '../../../chat/presentation/chat_route_extra.dart';
import '../../../chat/presentation/widgets/chat_conversation_tile.dart';
import '../../../chat/presentation/widgets/chat_person_search.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_loading_skeletons.dart';
import 'admin_create_chat_group_page.dart';

enum _AdminInboxFilter { all, groups, teachers, parents, supervisors }

/// Live window size of the Admin inbox; older threads load by cursor.
const adminInboxPageSize = 30;

/// Admin chat inbox — academy-wide oversight plus the Admin's own threads
/// and groups, newest first, paged.
class AdminChatInboxPage extends StatefulWidget {
  const AdminChatInboxPage({super.key});

  @override
  State<AdminChatInboxPage> createState() => _AdminChatInboxPageState();
}

class _AdminChatInboxPageState extends State<AdminChatInboxPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final ChatGroupsRepository _groups = resolveChatGroupsRepository();
  _AdminInboxFilter _filter = _AdminInboxFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWatch());
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q == _query) return;
      setState(() => _query = q);
    });
    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      if (pos.pixels >= pos.maxScrollExtent - 200) _loadMore();
    });
  }

  void _startWatch() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    sl<ChatConversationsBloc>().add(
      StartWatchingAllConversationsEvent(
        auth.user.uid,
        pageSize: adminInboxPageSize,
      ),
    );
  }

  void _loadMore() {
    final bloc = sl<ChatConversationsBloc>();
    final s = bloc.state;
    if (s.hasMoreConversations && !s.loadingMoreConversations) {
      bloc.add(const LoadMoreConversationsEvent());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<ConversationEntity> _visible(
    List<ConversationEntity> all,
    String currentUid,
  ) {
    Iterable<ConversationEntity> list = all.where((c) {
      if (_filter == _AdminInboxFilter.all) return true;
      if (_filter == _AdminInboxFilter.groups) return c.isGroup;
      final roles = c.participants.map((p) => p.role).toSet();
      return switch (_filter) {
        _AdminInboxFilter.teachers => roles.contains(AppRoles.teacher),
        _AdminInboxFilter.parents => roles.contains(AppRoles.parent),
        _AdminInboxFilter.supervisors => roles.contains(AppRoles.supervisor),
        _ => true,
      };
    });
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((c) {
        final title = c.displayTitleForObserver(currentUid).toLowerCase();
        return '$title ${c.lastMessage ?? ''}'.toLowerCase().contains(q);
      });
    }
    return list.toList();
  }

  void _open(ConversationEntity conv, String uid) {
    final isMine = conv.includesParticipant(uid);
    context.push(
      '${AppRoutes.admin}/chat/${conv.id}',
      extra: {
        ChatRouteExtra.nameKey: conv.displayTitleForObserver(uid),
        ChatRouteExtra.imageKey: isMine && !conv.isGroup
            ? conv.otherParticipant(uid).profileImageUrl
            : null,
        ChatRouteExtra.readOnlyKey: (!isMine).toString(),
      },
    );
  }

  Future<void> _openNewMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('inbox-new-chat'),
                leading: const Icon(Icons.chat_outlined),
                title: const Text('محادثة جديدة'),
                subtitle: const Text('معلم أو مشرف أو ولي أمر'),
                onTap: () => Navigator.pop(ctx, 'chat'),
              ),
              ListTile(
                key: const Key('inbox-new-group'),
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('مجموعة جديدة'),
                subtitle: const Text('اختر الأعضاء وحدّد اسم المجموعة'),
                onTap: () => Navigator.pop(ctx, 'group'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'chat') await _openNewChat();
    if (choice == 'group') await _openNewGroup();
  }

  Future<void> _openNewGroup() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AdminCreateChatGroupPage(
          create: _groups.createGroup,
          search: (q) => _groups.searchPeople(q, excludeUid: auth.user.uid),
        ),
      ),
    );
    if (id == null || !mounted) return;
    context.push(
      '${AppRoutes.admin}/chat/$id',
      extra: {ChatRouteExtra.nameKey: 'مجموعة'},
    );
  }

  Future<void> _openNewChat() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    final hit = await showModalBottomSheet<ChatPersonHit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'محادثة جديدة',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ChatPersonSearch(
                  search: (q) => _groups.searchPeople(
                    q,
                    excludeUid: auth.user.uid,
                    roles: const [
                      AppRoles.teacher,
                      AppRoles.supervisor,
                      AppRoles.parent,
                    ],
                  ),
                  onTap: (h) => Navigator.pop(ctx, h),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (hit == null || !mounted) return;

    final other = hit.toParticipant();
    final current = ChatParticipantEntity(
      uid: auth.user.uid,
      name: auth.user.name,
      role: auth.user.role,
      profileImageUrl: auth.user.profileImageUrl,
    );
    if (!ChatPermissionPolicy.canChat(current.role, other.role)) {
      AppSnackBar.showError(context, 'غير مسموح بفتح هذه المحادثة');
      return;
    }

    final chatBloc = sl<ChatConversationsBloc>();
    chatBloc.add(const ResetStartConversationEvent());
    chatBloc.add(StartConversationEvent(currentUser: current, otherUser: other));
    final startState = await chatBloc.stream.firstWhere(
      (s) =>
          s.startConversationStatus == SubmissionStatus.success ||
          s.startConversationStatus == SubmissionStatus.error,
    );
    if (!mounted) return;
    final conv = startState.startedConversation;
    chatBloc.add(const ResetStartConversationEvent());
    if (startState.startConversationStatus == SubmissionStatus.error ||
        conv == null) {
      AppSnackBar.showError(
        context,
        startState.startConversationError ?? 'تعذر فتح المحادثة',
      );
      return;
    }
    context.push(
      '${AppRoutes.admin}/chat/${conv.id}',
      extra: {
        ChatRouteExtra.nameKey: other.name,
        ChatRouteExtra.imageKey: other.profileImageUrl,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : '';

    Widget chip(String label, _AdminInboxFilter f) => AdminFilterChip(
      label: label,
      selected: _filter == f,
      onTap: () => setState(() => _filter = f),
    );

    return AdminSubpageScaffold(
      title: 'الرسائل',
      actions: [
        AdminIconButton(
          key: const Key('inbox-new'),
          icon: Icons.add_rounded,
          onTap: _openNewMenu,
        ),
        const SizedBox(width: 8),
      ],
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                chip('الكل', _AdminInboxFilter.all),
                chip('المجموعات', _AdminInboxFilter.groups),
                chip('المعلمون', _AdminInboxFilter.teachers),
                chip('أولياء الأمور', _AdminInboxFilter.parents),
                chip('المشرفون', _AdminInboxFilter.supervisors),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: AdminSearchField(
              controller: _searchCtrl,
              hint: 'ابحث في المحادثات المعروضة',
            ),
          ),
          Expanded(
            child: BlocBuilder<ChatConversationsBloc, ChatConversationsState>(
              bloc: sl<ChatConversationsBloc>(),
              builder: (context, state) {
                if (state.conversationsStatus == SectionStatus.loading ||
                    state.conversationsStatus == SectionStatus.initial) {
                  return const AdminChatInboxSkeleton();
                }
                if (state.conversationsStatus == SectionStatus.error &&
                    state.conversations.isEmpty) {
                  return AppErrorWidget(
                    message: state.conversationsError ?? 'تعذر التحميل',
                    onRetry: _startWatch,
                  );
                }

                final all = state.conversations;
                final items = _visible(all, uid);
                if (all.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: AdminPlaceholderCard(
                      icon: Icons.forum_outlined,
                      title: 'لا محادثات',
                      message:
                          'لا توجد محادثات في الأكاديمية حالياً. ابدأ محادثة أو أنشئ مجموعة من زر +.',
                    ),
                  );
                }
                final footer = state.hasMoreConversations ||
                    state.loadingMoreConversations;
                return ListView.separated(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                  itemCount: (items.isEmpty ? 1 : items.length) +
                      (footer ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 78,
                    endIndent: 16,
                    color: AppColors.border,
                  ),
                  itemBuilder: (context, i) {
                    if (items.isEmpty && i == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'لا نتائج مطابقة ضمن المحادثات المعروضة',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    final index = items.isEmpty ? i - 1 : i;
                    if (index >= items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: state.loadingMoreConversations
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : TextButton(
                                  key: const Key('inbox-load-more'),
                                  onPressed: _loadMore,
                                  child: const Text('عرض محادثات أقدم'),
                                ),
                        ),
                      );
                    }
                    final conv = items[index];
                    return ChatConversationTile(
                      key: Key('inbox-${conv.id}'),
                      conversation: conv,
                      viewerUid: uid,
                      observer: !conv.includesParticipant(uid),
                      onTap: () => _open(conv, uid),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
