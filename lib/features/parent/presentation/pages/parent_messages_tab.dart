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
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../domain/parent_household.dart';
import '../bloc/parent_bloc.dart';
import '../parent_destinations.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';
import '../widgets/parent_user_avatar.dart';

class ParentMessagesTab extends StatefulWidget {
  const ParentMessagesTab({super.key});

  @override
  State<ParentMessagesTab> createState() => _ParentMessagesTabState();
}

class _ParentMessagesTabState extends State<ParentMessagesTab> {
  static const _tabs = [
    (role: AppRoles.teacher, label: 'المعلم'),
    (role: AppRoles.supervisor, label: 'المشرف'),
    (role: AppRoles.admin, label: 'الإدارة'),
  ];

  int _tab = 0;
  String _query = '';
  bool _starting = false;

  Future<void> _startChat(ParentStaffContact contact) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated || _starting) return;
    setState(() => _starting = true);

    final conversations = sl<ChatConversationsBloc>().state.conversations;
    for (final conversation in conversations) {
      final other = conversation.otherParticipant(auth.user.uid);
      if (other.uid == contact.uid) {
        setState(() => _starting = false);
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : '';
    final staff = context.select<ParentBloc, List<ParentStaffContact>>(
      (bloc) => bloc.state.staffContacts,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocListener<ChatConversationsBloc, ChatConversationsState>(
        bloc: sl<ChatConversationsBloc>(),
        listenWhen: (p, c) =>
            p.startConversationStatus != c.startConversationStatus,
        listener: (context, state) async {
          if (!_starting) return;
          if (state.startConversationStatus == SubmissionStatus.error) {
            setState(() => _starting = false);
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
            sl<ChatConversationsBloc>().add(const ResetStartConversationEvent());
            setState(() => _starting = false);
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
            title: const Text('الرسائل'),
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'بحث في المحادثات...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              _ContactsStrip(
                contacts: staff
                    .where((c) => c.role == _tabs[_tab].role)
                    .toList(),
                onTap: _startChat,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(_tabs[i].label),
                        selected: _tab == i,
                        onSelected: (_) => setState(() => _tab = i),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: BlocBuilder<ChatConversationsBloc, ChatConversationsState>(
                  bloc: sl<ChatConversationsBloc>(),
                  builder: (context, state) {
                    if (state.conversationsStatus == SectionStatus.initial ||
                        state.conversationsStatus == SectionStatus.loading) {
                      return const ParentListCardsSkeleton();
                    }
                    if (state.conversationsStatus == SectionStatus.error) {
                      return AppErrorWidget(
                        message:
                            state.conversationsError ?? 'تعذر تحميل الرسائل',
                        onRetry: () {
                          if (uid.isEmpty) return;
                          sl<ChatConversationsBloc>().add(
                            StartWatchingConversationsEvent(uid),
                          );
                        },
                      );
                    }

                    final role = _tabs[_tab].role;
                    final items = state.conversations.where((c) {
                      final other = c.otherParticipant(uid);
                      if (other.role != role) return false;
                      if (_query.isEmpty) return true;
                      return other.name.contains(_query) ||
                          (c.lastMessage ?? '').contains(_query);
                    }).toList();

                    if (items.isEmpty) {
                      return ParentEmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'لا توجد محادثات مع ${_tabs[_tab].label}',
                        message:
                            'التواصل 1:1 مع المعلم أو المشرف أو الإدارة من جهات الاتصال أعلاه.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _ConversationTile(
                          conversation: items[index],
                          currentUid: uid,
                          roleLabel: _tabs[_tab].label,
                        );
                      },
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

class _ContactsStrip extends StatelessWidget {
  final List<ParentStaffContact> contacts;
  final ValueChanged<ParentStaffContact> onTap;

  const _ContactsStrip({required this.contacts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: contacts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final contact = contacts[index];
          final name = contact.name.trim().isEmpty ? '—' : contact.name.trim();
          return InkWell(
            onTap: () => onTap(contact),
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  ParentUserAvatar(
                    name: name,
                    imageUrl: contact.profileImageUrl,
                    radius: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationEntity conversation;
  final String currentUid;
  final String roleLabel;

  const _ConversationTile({
    required this.conversation,
    required this.currentUid,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final other = conversation.otherParticipant(currentUid);
    final title = other.name.trim().isEmpty ? roleLabel : other.name.trim();
    return AppCard(
      onTap: () => ParentDestinations.chat(
        context,
        conversationId: conversation.id,
        title: title,
        imageUrl: other.profileImageUrl,
      ),
      color: conversation.hasUnread()
          ? AppColors.primaryLight.withValues(alpha: 0.45)
          : null,
      child: Row(
        children: [
          if (conversation.hasUnread())
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title, style: AppTextStyles.titleLarge),
                const SizedBox(height: 4),
                Text(
                  conversation.lastMessage?.trim().isNotEmpty == true
                      ? conversation.lastMessage!.trim()
                      : 'لا توجد رسائل بعد',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ParentUserAvatar(
            name: other.name,
            imageUrl: other.profileImageUrl,
            radius: 22,
          ),
        ],
      ),
    );
  }
}
