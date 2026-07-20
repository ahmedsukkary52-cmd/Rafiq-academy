import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../../core/di/injection_container.dart';

class TeacherMessagesTab extends StatefulWidget {
  const TeacherMessagesTab({super.key});

  @override
  State<TeacherMessagesTab> createState() => _TeacherMessagesTabState();
}

class _TeacherMessagesTabState extends State<TeacherMessagesTab> {
  // فلتر المحادثات: أولياء أمور / مشرفون / إدارة
  int _filterIndex = 0;
  final _filters = const ['أولياء الأمور', 'المشرفون', 'الإدارة'];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      sl<ChatConversationsBloc>().add(
        StartWatchingConversationsEvent(authState.user.uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الرسائل'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // ── فلاتر ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: Row(
              children: List.generate(_filters.length, (i) {
                final selected = i == _filterIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _filterIndex = i),
                    child: Container(
                      margin: EdgeInsets.only(left: i < 2 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        _filters[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── بحث ───────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
            child: AppTextField(
              hint: 'بحث في المحادثات...',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textHint),
            ),
          ),

          const SizedBox(height: 8),

          // ── قائمة المحادثات ────────────────────────────────────
          Expanded(
            child: BlocBuilder<ChatConversationsBloc, ChatConversationsState>(
              bloc: sl<ChatConversationsBloc>(),
              builder: (context, state) {
                final authState = context.read<AuthBloc>().state;
                final currentUid = authState is AuthAuthenticated
                    ? authState.user.uid
                    : '';

                if (state.conversationsStatus == SectionStatus.loading) {
                  return const AppLoadingWidget();
                }

                if (state.conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: AppColors.textHint.withOpacity(0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد رسائل بعد',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: state.conversations.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) {
                    final conv = state.conversations[i];
                    final other = conv.otherParticipant(currentUid);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingM,
                        vertical: 6,
                      ),
                      onTap: () => context.push('/teacher/chat/${conv.id}'),
                      leading: Stack(
                        children: [
                          UserAvatar(name: other.name),
                          if (conv.unreadCount > 0)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${conv.unreadCount}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        '${other.name} — ${_roleName(other.role)}',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: conv.unreadCount > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      subtitle: Text(
                        conv.lastMessage ?? '',
                        style: AppTextStyles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                      ),
                      trailing: conv.lastMessageAt != null
                          ? Text(
                              _timeAgo(conv.lastMessageAt!),
                              style: AppTextStyles.labelSmall,
                            )
                          : null,
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

  String _roleName(String role) => switch (role) {
    'student' => 'طالب',
    'parent' => 'ولي أمر',
    'supervisor' => 'مشرف',
    'admin' => 'إدارة',
    _ => role,
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دق';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return 'أمس';
  }
}
