import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/chat_entities.dart';
import '../bloc/chat_conversations_bloc.dart';
import '../bloc/chat_conversations_event.dart';
import '../bloc/chat_conversations_state.dart';

class ChatConversationsPage extends StatefulWidget {
  const ChatConversationsPage({super.key});

  @override
  State<ChatConversationsPage> createState() => _ChatConversationsPageState();
}

class _ChatConversationsPageState extends State<ChatConversationsPage> {
  late final ChatConversationsBloc _bloc;
  String _currentUid = '';

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) _currentUid = authState.user.uid;
    _bloc = sl<ChatConversationsBloc>();
    _bloc.add(StartWatchingConversationsEvent(_currentUid));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('المحادثات')),
        body: BlocBuilder<ChatConversationsBloc, ChatConversationsState>(
          buildWhen: (previous, current) =>
              previous.conversationsStatus != current.conversationsStatus ||
              previous.conversations != current.conversations ||
              previous.conversationsError != current.conversationsError,
          builder: (context, state) {
            if (state.conversationsStatus == SectionStatus.loading) {
              return const AppLoadingWidget();
            }
            if (state.conversationsStatus == SectionStatus.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.conversationsError ?? 'حدث خطأ',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _bloc.add(
                        StartWatchingConversationsEvent(_currentUid),
                      ),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }
            if (state.conversations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 64,
                      color: AppColors.textHint.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'لا توجد محادثات بعد',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              itemCount: state.conversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final conversation = state.conversations[index];
                final otherUser = conversation.otherParticipant(_currentUid);
                return _ConversationItem(
                  conversation: conversation,
                  otherUser: otherUser,
                  onTap: () {
                    context.go(
                      '/teacher/chat/${conversation.id}',
                      extra: {
                        'name': otherUser.name,
                        'image': otherUser.profileImageUrl,
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ConversationItem extends StatelessWidget {
  final ConversationEntity conversation;
  final ChatParticipantEntity otherUser;
  final VoidCallback onTap;

  const _ConversationItem({
    required this.conversation,
    required this.otherUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (conversation.hasUnread())
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      otherUser.name,
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (conversation.lastMessage != null)
                  Text(
                    conversation.lastMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          UserAvatar(
            name: otherUser.name,
            imageUrl: otherUser.profileImageUrl,
            size: 48,
          ),
        ],
      ),
    );
  }
}
