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
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../chat/presentation/chat_route_extra.dart';
import '../../domain/entities/teacher_management_entity.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_loading_skeletons.dart';

enum _AdminInboxFilter { all, teachers, parents, supervisors }

/// Admin chat inbox — reuses [ChatConversationsBloc] (academy-wide for admin uid).
class AdminChatInboxPage extends StatefulWidget {
  const AdminChatInboxPage({super.key});

  @override
  State<AdminChatInboxPage> createState() => _AdminChatInboxPageState();
}

class _AdminChatInboxPageState extends State<AdminChatInboxPage> {
  final _searchCtrl = TextEditingController();
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
  }

  void _startWatch() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    sl<ChatConversationsBloc>().add(
      StartWatchingAllConversationsEvent(auth.user.uid),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ConversationEntity> _visible(
    List<ConversationEntity> all,
    String currentUid,
  ) {
    Iterable<ConversationEntity> list = all;
    list = list.where((c) {
      if (_filter == _AdminInboxFilter.all) return true;
      final roles = c.participants.map((p) => p.role).toSet();
      // For third-party chats, match if any participant has the role.
      return switch (_filter) {
        _AdminInboxFilter.teachers => roles.contains(AppRoles.teacher),
        _AdminInboxFilter.parents => roles.contains(AppRoles.parent),
        _AdminInboxFilter.supervisors => roles.contains(AppRoles.supervisor),
        _AdminInboxFilter.all => true,
      };
    });
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((c) {
        final title = c.displayTitleForObserver(currentUid).toLowerCase();
        final hay = '$title ${c.lastMessage ?? ''}'.toLowerCase();
        return hay.contains(q);
      });
    }
    return list.toList();
  }

  Future<void> _openNewChat() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    context.read<AdminBloc>().add(const LoadAllTeachersEvent());
    final teacher = await showModalBottomSheet<TeacherManagementEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _AdminNewChatSheet(),
    );
    if (teacher == null || !mounted) return;

    final other = ChatParticipantEntity(
      uid: teacher.uid,
      name: teacher.name,
      role: AppRoles.teacher,
      profileImageUrl: teacher.profileImageUrl,
    );
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
    chatBloc.add(
      StartConversationEvent(currentUser: current, otherUser: other),
    );

    final startState = await chatBloc.stream.firstWhere(
      (s) =>
          s.startConversationStatus == SubmissionStatus.success ||
          s.startConversationStatus == SubmissionStatus.error,
    );
    if (!mounted) return;

    if (startState.startConversationStatus == SubmissionStatus.error ||
        startState.startedConversation == null) {
      AppSnackBar.showError(
        context,
        startState.startConversationError ?? 'تعذر فتح المحادثة',
      );
      chatBloc.add(const ResetStartConversationEvent());
      return;
    }

    final conv = startState.startedConversation!;
    chatBloc.add(const ResetStartConversationEvent());
    context.push(
      '${AppRoutes.admin}/chat/${conv.id}',
      extra: {
        ChatRouteExtra.nameKey: other.name,
        ChatRouteExtra.imageKey: other.profileImageUrl,
      },
    );
  }

  static String _roleLabel(String role) => switch (role) {
    AppRoles.teacher => 'معلم',
    AppRoles.parent => 'ولي أمر',
    AppRoles.supervisor => 'مشرف',
    AppRoles.admin => 'إدارة',
    _ => role,
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : '';

    return AdminSubpageScaffold(
      title: 'الرسائل',
      actions: [
        AdminIconButton(icon: Icons.add_rounded, onTap: _openNewChat),
        const SizedBox(width: 8),
      ],
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                AdminFilterChip(
                  label: 'الكل',
                  selected: _filter == _AdminInboxFilter.all,
                  onTap: () => setState(() => _filter = _AdminInboxFilter.all),
                ),
                AdminFilterChip(
                  label: 'المعلمون',
                  selected: _filter == _AdminInboxFilter.teachers,
                  onTap: () =>
                      setState(() => _filter = _AdminInboxFilter.teachers),
                ),
                AdminFilterChip(
                  label: 'أولياء الأمور',
                  selected: _filter == _AdminInboxFilter.parents,
                  onTap: () =>
                      setState(() => _filter = _AdminInboxFilter.parents),
                ),
                AdminFilterChip(
                  label: 'المشرفون',
                  selected: _filter == _AdminInboxFilter.supervisors,
                  onTap: () =>
                      setState(() => _filter = _AdminInboxFilter.supervisors),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: AdminSearchField(
              controller: _searchCtrl,
              hint: 'ابحث في المحادثات',
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
                if (state.conversationsStatus == SectionStatus.error) {
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
                          'لا توجد محادثات في الأكاديمية حالياً. عند إنشاء محادثات ستظهر هنا للمراقبة.',
                    ),
                  );
                }
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isNotEmpty || _filter != _AdminInboxFilter.all
                          ? 'لا نتائج مطابقة للبحث أو الفلتر'
                          : 'لا توجد محادثات',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 78,
                    endIndent: 16,
                    color: AppColors.border,
                  ),
                  itemBuilder: (context, i) {
                    final conv = items[i];
                    final title = conv.displayTitleForObserver(uid);
                    final isMine = conv.includesParticipant(uid);
                    final subtitleRole = isMine
                        ? _roleLabel(conv.otherParticipant(uid).role)
                        : conv.participants
                              .map((p) => _roleLabel(p.role))
                              .join(' · ');
                    return ListTile(
                      onTap: () => context.push(
                        '${AppRoutes.admin}/chat/${conv.id}',
                        extra: {
                          ChatRouteExtra.nameKey: title,
                          ChatRouteExtra.imageKey: isMine
                              ? conv.otherParticipant(uid).profileImageUrl
                              : null,
                          ChatRouteExtra.readOnlyKey: (!isMine).toString(),
                        },
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          title.isNotEmpty ? title.characters.first : '?',
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                      title: Text(
                        title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '$subtitleRole · ${conv.lastMessage ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            adminTimeAgo(conv.lastMessageAt),
                            style: AppTextStyles.labelSmall,
                          ),
                          if (!isMine)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'مراقبة',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else if (conv.unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${conv.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
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

class _AdminNewChatSheet extends StatelessWidget {
  const _AdminNewChatSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'محادثة جديدة — معلم',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            BlocBuilder<AdminBloc, AdminState>(
              builder: (context, state) {
                if (state.teachersStatus == SectionStatus.loading) {
                  return const AdminChatInboxSkeleton();
                }
                if (state.teachers.isEmpty) {
                  return const Text('لا يوجد معلمون');
                }
                return SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: state.teachers.length,
                    itemBuilder: (_, i) {
                      final t = state.teachers[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            t.name.isNotEmpty ? t.name.characters.first : 'م',
                          ),
                        ),
                        title: Text(t.name),
                        onTap: () => Navigator.pop(context, t),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
