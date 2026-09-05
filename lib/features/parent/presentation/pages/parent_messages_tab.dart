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
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';
import '../widgets/parent_user_avatar.dart';

class ParentMessagesTab extends StatefulWidget {
  const ParentMessagesTab({super.key});

  @override
  State<ParentMessagesTab> createState() => _ParentMessagesTabState();
}

enum _ChatIntent { none, seed, open }

class _ParentMessagesTabState extends State<ParentMessagesTab> {
  static const _tabs = [
    (role: AppRoles.teacher, label: 'المعلم'),
    (role: AppRoles.supervisor, label: 'المشرف'),
    (role: AppRoles.admin, label: 'الإدارة'),
  ];

  int _tab = 0;
  String _query = '';
  _ChatIntent _intent = _ChatIntent.none;
  final _seededUids = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chat = sl<ChatConversationsBloc>().state;
      if (chat.conversationsStatus != SectionStatus.loaded) return;
      _seedLinkedChats(
        uid: _uid,
        contacts: _roleContacts(context.read<ParentBloc>().state.staffContacts),
        conversations: chat.conversations,
      );
    });
  }

  bool get _busy => _intent != _ChatIntent.none;

  String get _uid {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.user.uid : '';
  }

  List<ParentStaffContact> _roleContacts(List<ParentStaffContact> staff) {
    final role = _tabs[_tab].role;
    return [
      for (final contact in staff)
        if (contact.role == role) contact,
    ];
  }

  ConversationEntity? _existingChat({
    required String uid,
    required String otherUid,
    required List<ConversationEntity> conversations,
  }) {
    for (final conversation in conversations) {
      if (conversation.otherParticipant(uid).uid == otherUid) {
        return conversation;
      }
    }
    return null;
  }

  void _seedLinkedChats({
    required String uid,
    required List<ParentStaffContact> contacts,
    required List<ConversationEntity> conversations,
  }) {
    if (_busy || uid.isEmpty) return;

    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    for (final contact in contacts) {
      if (_seededUids.contains(contact.uid)) continue;
      if (_existingChat(
            uid: uid,
            otherUid: contact.uid,
            conversations: conversations,
          ) !=
          null) {
        _seededUids.add(contact.uid);
        continue;
      }

      _seededUids.add(contact.uid);
      if (mounted) {
        setState(() => _intent = _ChatIntent.seed);
      } else {
        _intent = _ChatIntent.seed;
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
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : '';
    final staff = context.select<ParentBloc, List<ParentStaffContact>>(
      (bloc) => bloc.state.staffContacts,
    );
    final children = context.select<ParentBloc, List<ParentChildSnapshot>>(
      (bloc) => bloc.state.childrenSnapshots,
    );
    final roleContacts = _roleContacts(staff);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<ChatConversationsBloc, ChatConversationsState>(
        bloc: sl<ChatConversationsBloc>(),
        listenWhen: (p, c) =>
            p.startConversationStatus != c.startConversationStatus ||
            p.conversations != c.conversations,
        listener: (context, state) async {
          if (state.conversationsStatus == SectionStatus.loaded) {
            _seedLinkedChats(
              uid: uid,
              contacts: roleContacts,
              conversations: state.conversations,
            );
          }

          if (state.startConversationStatus == SubmissionStatus.error) {
            final wasOpen = _intent == _ChatIntent.open;
            setState(() => _intent = _ChatIntent.none);
            if (wasOpen && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.startConversationError ?? 'تعذر بدء المحادثة',
                  ),
                ),
              );
            }
            return;
          }

          if (state.startConversationStatus == SubmissionStatus.success &&
              state.startedConversation != null) {
            final conversation = state.startedConversation!;
            sl<ChatConversationsBloc>().add(
              const ResetStartConversationEvent(),
            );
            final shouldOpen = _intent == _ChatIntent.open;
            setState(() => _intent = _ChatIntent.none);
            if (shouldOpen) {
              final other = conversation.otherParticipant(uid);
              if (!mounted) return;
              await ParentDestinations.chat(
                context,
                conversationId: conversation.id,
                title: other.name,
                imageUrl: other.profileImageUrl,
              );
            } else {
              _seedLinkedChats(
                uid: uid,
                contacts: roleContacts,
                conversations: sl<ChatConversationsBloc>().state.conversations,
              );
            }
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('الرسائل'),
              automaticallyImplyLeading: false,
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(_tabs[i].label),
                          selected: _tab == i,
                          onSelected: (_) {
                            if (_tab == i) return;
                            setState(() => _tab = i);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              final chat = sl<ChatConversationsBloc>().state;
                              if (chat.conversationsStatus !=
                                  SectionStatus.loaded) {
                                return;
                              }
                              _seedLinkedChats(
                                uid: _uid,
                                contacts: _roleContacts(
                                  context
                                      .read<ParentBloc>()
                                      .state
                                      .staffContacts,
                                ),
                                conversations: chat.conversations,
                              );
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'بحث في المحادثات...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                Expanded(
                  child: _ConversationsBody(
                    uid: uid,
                    query: _query,
                    role: _tabs[_tab].role,
                    roleLabel: _tabs[_tab].label,
                    contacts: roleContacts,
                    children: children,
                    state: state,
                    seeding: _intent == _ChatIntent.seed,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RingAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _RingAvatar({required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: ParentUserAvatar(
        name: name,
        imageUrl: imageUrl,
        radius: 26,
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.primaryDark,
      ),
    );
  }
}

class _ConversationsBody extends StatelessWidget {
  final String uid;
  final String query;
  final String role;
  final String roleLabel;
  final List<ParentStaffContact> contacts;
  final List<ParentChildSnapshot> children;
  final ChatConversationsState state;
  final bool seeding;

  const _ConversationsBody({
    required this.uid,
    required this.query,
    required this.role,
    required this.roleLabel,
    required this.contacts,
    required this.children,
    required this.state,
    required this.seeding,
  });

  @override
  Widget build(BuildContext context) {
    if (state.conversationsStatus == SectionStatus.initial ||
        state.conversationsStatus == SectionStatus.loading) {
      return const ParentListCardsSkeleton();
    }
    if (state.conversationsStatus == SectionStatus.error) {
      return AppErrorWidget(
        message: state.conversationsError ?? 'تعذر تحميل الرسائل',
        onRetry: () {
          if (uid.isEmpty) return;
          sl<ChatConversationsBloc>().add(StartWatchingConversationsEvent(uid));
        },
      );
    }

    final items = state.conversations.where((conversation) {
      final other = conversation.otherParticipant(uid);
      if (other.role != role) return false;
      if (query.isEmpty) return true;
      return other.name.contains(query) ||
          (conversation.lastMessage ?? '').contains(query);
    }).toList();

    if (items.isEmpty) {
      if (seeding) {
        return const ParentListCardsSkeleton(itemCount: 3);
      }
      if (contacts.isEmpty) {
        return ParentEmptyState(
          icon: Icons.chat_bubble_outline,
          title: 'لا يوجد $roleLabel مرتبط حالياً',
          message: role == AppRoles.admin
              ? 'عند توفر حساب إدارة ستظهر بطاقة المحادثة هنا.'
              : 'عند ربط أبنائك بحلقة ستظهر بطاقة $roleLabel هنا تلقائياً.',
        );
      }
      return ParentEmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'لا توجد محادثات مع $roleLabel بعد',
        message: 'ابدأ المحادثة من بطاقة الابن أو انتظر تجهيز المحادثة.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final conversation = items[index];
        final other = conversation.otherParticipant(uid);
        return _ConversationTile(
          conversation: conversation,
          currentUid: uid,
          roleLabel: roleLabel,
          relation: parentStaffRelationCaption(
            role: other.role,
            staffUid: other.uid,
            children: children,
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationEntity conversation;
  final String currentUid;
  final String roleLabel;
  final String relation;

  const _ConversationTile({
    required this.conversation,
    required this.currentUid,
    required this.roleLabel,
    required this.relation,
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
          _RingAvatar(name: other.name, imageUrl: other.profileImageUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  relation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: 2),
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
          if (conversation.hasUnread()) ...[
            const SizedBox(width: 8),
            _UnreadBadge(count: conversation.unreadCount),
          ],
          const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 9 ? '+9' : '$count',
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.onPrimary),
      ),
    );
  }
}
