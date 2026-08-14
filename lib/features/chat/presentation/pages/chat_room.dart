import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/chat_entities.dart';
import '../bloc/chat_conversations_bloc.dart';
import '../bloc/chat_conversations_state.dart';
import '../bloc/chat_room_bloc.dart';
import '../bloc/chat_room_event.dart';
import '../bloc/chat_room_state.dart';
import '../chat_message_alignment.dart';

/// Shared chat room — Figma 10 text chrome (Teacher + Student routes).
///
/// Text messaging only. No audio / attachments / presence / read receipts.
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
  int _lastMessageCount = 0;
  String _pendingSend = '';

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
    _pendingSend = text;
    _messageCtrl.clear();
    _chatBloc.add(SendMessageRequestedEvent(text));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  /// Prefer route `extra`; fall back to denormalized conversation participants.
  (String, String?) _resolvePeer(ChatParticipantEntity? peer) {
    final extraName = widget.otherUserName.trim();
    final peerName = peer?.name.trim() ?? '';
    final name = extraName.isNotEmpty &&
        extraName != 'محادثة' &&
        extraName != 'المعلم'
        ? extraName
        : (peerName.isNotEmpty
        ? peerName
        : (extraName.isNotEmpty ? extraName : 'محادثة'));

    final extraImage = widget.otherUserImage?.trim();
    final image = (extraImage != null && extraImage.isNotEmpty)
        ? extraImage
        : peer?.profileImageUrl;
    return (name, image);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocProvider.value(
        value: _chatBloc,
        child: BlocBuilder<ChatConversationsBloc, ChatConversationsState>(
          bloc: sl<ChatConversationsBloc>(),
          buildWhen: (p, c) => p.conversations != c.conversations,
          builder: (context, convState) {
            ConversationEntity? conversation;
            for (final c in convState.conversations) {
              if (c.id == widget.conversationId) {
                conversation = c;
                break;
              }
            }
            final peer = conversation != null && _currentUid.isNotEmpty
                ? conversation.otherParticipant(_currentUid)
                : null;
            final (name, imageUrl) = _resolvePeer(peer);

            return Scaffold(
              backgroundColor: const Color(0xFFF5FAFB),
              body: Column(
                children: [
                  _ChatRoomHeader(
                    name: name,
                    imageUrl: imageUrl,
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      }
                    },
                  ),
                  Expanded(
                    child: BlocConsumer<ChatRoomBloc, ChatRoomState>(
                      listenWhen: (p, c) =>
                      p.messages.length != c.messages.length ||
                          p.sendStatus != c.sendStatus,
                      listener: (context, state) {
                        if (state.messages.length > _lastMessageCount) {
                          _scrollToBottom();
                        }
                        _lastMessageCount = state.messages.length;
                        if (state.sendStatus == SubmissionStatus.error &&
                            _pendingSend.isNotEmpty &&
                            _messageCtrl.text.isEmpty) {
                          _messageCtrl.text = _pendingSend;
                        }
                        if (state.sendStatus == SubmissionStatus.success) {
                          _pendingSend = '';
                        }
                      },
                      buildWhen: (p, c) =>
                      p.messages != c.messages ||
                          p.messagesStatus != c.messagesStatus ||
                          p.messagesError != c.messagesError,
                      builder: (context, state) {
                        if (state.messagesStatus == SectionStatus.loading ||
                            state.messagesStatus == SectionStatus.initial) {
                          return const _MessagesSkeleton();
                        }

                        if (state.messagesStatus == SectionStatus.error) {
                          return AppErrorWidget(
                            message:
                            state.messagesError ?? 'تعذر تحميل الرسائل',
                            onRetry: () =>
                                _chatBloc.add(
                                  const WatchMessagesStartedEvent(),
                                ),
                          );
                        }

                        if (state.messages.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 52,
                                  color: AppColors.textHint
                                      .withValues(alpha: 0.45),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'ابدأ المحادثة',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final messages = state.messages;
                        final auth = context
                            .read<AuthBloc>()
                            .state;
                        final uid = auth is AuthAuthenticated
                            ? auth.user.uid
                            : _currentUid;
                        return ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: messages.length,
                          itemBuilder: (context, i) {
                            final msg = messages[i];
                            final isMine = msg.isMine(uid);
                            final showDate = i == 0 ||
                                !_sameDay(
                                  messages[i - 1].sentAt,
                                  msg.sentAt,
                                );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showDate) _DateChip(date: msg.sentAt),
                                Align(
                                  alignment: ChatMessageAlignment
                                      .bubbleAlignment(
                                    isMine: isMine,
                                  ),
                                  child: _MessageBubble(
                                    message: msg,
                                    isMine: isMine,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  BlocBuilder<ChatRoomBloc, ChatRoomState>(
                    buildWhen: (p, c) => p.sendError != c.sendError,
                    builder: (context, state) {
                      if (state.sendError == null) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        width: double.infinity,
                        color: AppColors.error.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
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
                    },
                  ),
                  _ComposerBar(
                    controller: _messageCtrl,
                    onSend: _sendMessage,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ChatRoomHeader extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final VoidCallback onBack;

  const _ChatRoomHeader({
    required this.name,
    required this.imageUrl,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery
        .paddingOf(context)
        .top;
    return Container(
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8EEF0), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF5FAFB),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _HeaderAvatar(name: name, imageUrl: imageUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            onPressed: null,
            icon: Icon(
              Icons.more_vert_rounded,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            tooltip: 'قريباً',
          ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _HeaderAvatar({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name
        .trim()
        .isEmpty ? '?' : name.trim()[0];
    final url = imageUrl?.trim();
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFFEF3C7),
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Text(
        initial,
        style: AppTextStyles.titleMedium.copyWith(
          color: const Color(0xFF92400E),
          fontWeight: FontWeight.w800,
        ),
      )
          : null,
    );
  }
}

// ── Bubbles ───────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final time = formatTimeHm12Ar(message.sentAt);
    final maxWidth = ChatMessageAlignment.maxBubbleWidth(
      MediaQuery
          .sizeOf(context)
          .width,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: ChatMessageAlignment.contentCrossAxis(
            isMine: isMine,
          ),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : AppColors.surface,
                borderRadius: ChatMessageAlignment.bubbleBorderRadius(
                  isMine: isMine,
                ).resolve(Directionality.of(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isMine ? AppColors.onPrimary : AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
                textAlign: TextAlign.start,
                softWrap: true,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                time,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;

  const _DateChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final label = d == today
        ? 'اليوم'
        : d == today.subtract(const Duration(days: 1))
        ? 'أمس'
        : '${date.day}/${date.month}/${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEF0),
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Composer ──────────────────────────────────────────────────────────────────

class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ComposerBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: Color(0xFFE8EEF0), width: 0.8),
          ),
        ),
        child: Row(
          children: [
            // Decorative mic — not wired (no audio in this phase).
            Opacity(
              opacity: 0.35,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_none_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.send,
                keyboardType: TextInputType.multiline,
                style: AppTextStyles.bodyLarge.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '...اكتب رسالة',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5FAFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Color(0xFFE8EEF0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Color(0xFFE8EEF0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.2,
                    ),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.send_rounded,
                    color: AppColors.onPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _MessagesSkeleton extends StatefulWidget {
  const _MessagesSkeleton();

  @override
  State<_MessagesSkeleton> createState() => _MessagesSkeletonState();
}

class _MessagesSkeletonState extends State<_MessagesSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.35, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
        Widget bubble({required bool mine, required double width}) {
          return Align(
            alignment: ChatMessageAlignment.bubbleAlignment(isMine: mine),
            child: Container(
              width: width,
              height: 44,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: bone,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 22,
                  decoration: BoxDecoration(
                    color: bone,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              bubble(mine: true, width: 210),
              bubble(mine: false, width: 180),
              bubble(mine: true, width: 160),
              bubble(mine: false, width: 220),
            ],
          ),
        );
      },
    );
  }
}
