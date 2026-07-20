import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/chat_entities.dart';
import '../../presentation/bloc/chat_room_bloc.dart';
import '../../presentation/bloc/chat_room_event.dart';
import '../../presentation/bloc/chat_room_state.dart';

class ChatRoomPage extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserImage;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserImage,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final ChatRoomBloc _chatBloc;
  String _currentUid = '';

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) _currentUid = authState.user.uid;

    _chatBloc = sl<ChatRoomBloc>(
      param1: widget.conversationId,
      param2: _currentUid,
    );
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _chatBloc.close();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    _messageCtrl.clear();
    _chatBloc.add(SendMessageRequestedEvent(text));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _chatBloc,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'متصل الآن',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              UserAvatar(
                name: widget.otherUserName,
                imageUrl: widget.otherUserImage,
                size: 36,
                backgroundColor: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            // ── قائمة الرسائل ──────────────────────────────────
            Expanded(
              child: BlocBuilder<ChatRoomBloc, ChatRoomState>(
                builder: (context, state) {
                  if (state.messagesStatus == SectionStatus.loading) {
                    return const AppLoadingWidget();
                  }

                  if (state.messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 56,
                            color: AppColors.textHint.withOpacity(0.4),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'ابدأ المحادثة',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  // نمرر عناصر بتاريخ لتجميع الرسائل بالأيام
                  final messages = state.messages;
                  _scrollToBottom();

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                      vertical: AppSizes.paddingM,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final isMine = msg.isMine(_currentUid);
                      final showDate =
                          i == 0 ||
                          !_sameDay(messages[i - 1].sentAt, msg.sentAt);

                      return Column(
                        children: [
                          if (showDate) _DateDivider(date: msg.sentAt),
                          _MessageBubble(message: msg, isMine: isMine),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // ── Error ──────────────────────────────────────────
            BlocBuilder<ChatRoomBloc, ChatRoomState>(
              builder: (context, state) {
                if (state.sendError != null) {
                  return Container(
                    color: AppColors.error.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                      vertical: 6,
                    ),
                    child: Text(
                      state.sendError!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // ── حقل الإرسال ────────────────────────────────────
            _MessageInputBar(controller: _messageCtrl, onSend: _sendMessage),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;
}

// ══════════════════════════════════════════════════════════════════════════════
// _MessageBubble
// ══════════════════════════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMine) ...[
            // وقت الإرسال يمين
            Text(_formatTime(message.sentAt), style: AppTextStyles.labelSmall),
            const SizedBox(width: 6),
            // نقاط القراءة
            const Text(
              '✓✓',
              style: TextStyle(fontSize: 11, color: AppColors.primary),
            ),
            const SizedBox(width: 6),
          ],

          // فقاعة الرسالة
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppSizes.radiusL),
                  topRight: const Radius.circular(AppSizes.radiusL),
                  bottomLeft: isMine
                      ? Radius.zero
                      : const Radius.circular(AppSizes.radiusL),
                  bottomRight: isMine
                      ? const Radius.circular(AppSizes.radiusL)
                      : Radius.zero,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 14,
                  height: 1.5,
                  color: isMine ? Colors.white : AppColors.textPrimary,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),

          if (!isMine) ...[
            const SizedBox(width: 6),
            Text(_formatTime(message.sentAt), style: AppTextStyles.labelSmall),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'ص' : 'م';
    return '$h:$m $period';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DateDivider
// ══════════════════════════════════════════════════════════════════════════════

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = date.day == now.day && date.month == now.month
        ? 'اليوم'
        : '${date.day}/${date.month}/${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: AppTextStyles.labelSmall),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _MessageInputBar
// ══════════════════════════════════════════════════════════════════════════════

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingM,
          vertical: 8,
        ),
        child: Row(
          children: [
            // زرار الإرسال
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // زرار تحويل الاتجاه
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.textHint,
              size: 20,
            ),

            const SizedBox(width: 8),

            // حقل الكتابة
            Expanded(
              child: TextField(
                controller: controller,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                maxLines: null,
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  hintStyle: AppTextStyles.bodyMedium,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),

            const SizedBox(width: 8),

            // زرار الصوت
            const Icon(
              Icons.mic_none_rounded,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
