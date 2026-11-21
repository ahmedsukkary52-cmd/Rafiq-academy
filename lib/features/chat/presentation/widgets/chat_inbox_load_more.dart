import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../bloc/chat_conversations_bloc.dart';
import '../bloc/chat_conversations_event.dart';

/// Scroll + footer wiring for role/admin inboxes that use a bounded live
/// window (`pageSize`) and [LoadMoreConversationsEvent] for older threads.
class ChatInboxLoadMoreBinding {
  ChatInboxLoadMoreBinding({ChatConversationsBloc? bloc})
    : bloc = bloc ?? sl<ChatConversationsBloc>() {
    controller.addListener(_onScroll);
  }

  final ChatConversationsBloc bloc;
  final ScrollController controller = ScrollController();

  void _onScroll() {
    if (!controller.hasClients) return;
    final pos = controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) requestLoadMore();
  }

  void requestLoadMore() {
    final s = bloc.state;
    if (s.hasMoreConversations && !s.loadingMoreConversations) {
      bloc.add(const LoadMoreConversationsEvent());
    }
  }

  void dispose() {
    controller.dispose();
  }
}

/// Footer shown when more inbox pages exist or a page is in flight.
class ChatInboxLoadMoreFooter extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const ChatInboxLoadMoreFooter({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                key: const Key('inbox-load-more'),
                onPressed: onPressed,
                child: Text(
                  'عرض محادثات أقدم',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}
