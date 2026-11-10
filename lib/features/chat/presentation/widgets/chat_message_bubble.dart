import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../domain/entities/chat_entities.dart';
import '../bloc/chat_room_state.dart';
import '../chat_message_alignment.dart';
import '../media/chat_media_loader.dart';
import 'chat_media_views.dart';

class _BubbleFrame extends StatelessWidget {
  final bool isMine;
  final Widget child;
  final Widget footer;
  final VoidCallback? onLongPress;
  final bool tight;

  const _BubbleFrame({
    required this.isMine,
    required this.child,
    required this.footer,
    this.onLongPress,
    this.tight = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = ChatMessageAlignment.maxBubbleWidth(
      MediaQuery.sizeOf(context).width,
    );
    return Align(
      alignment: ChatMessageAlignment.bubbleAlignment(isMine: isMine),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: ChatMessageAlignment.contentCrossAxis(
              isMine: isMine,
            ),
            children: [
              GestureDetector(
                onLongPress: onLongPress,
                child: Container(
                  padding: tight
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                  child: child,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: footer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _bodyStyle(bool isMine) => AppTextStyles.bodyLarge.copyWith(
  color: isMine ? AppColors.onPrimary : AppColors.textPrimary,
  fontSize: 14,
  height: 1.45,
);

TextStyle get _metaStyle =>
    AppTextStyles.labelSmall.copyWith(color: AppColors.textHint, fontSize: 10);

/// A server-confirmed message (stream data only).
class ChatMessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMine;
  final ChatMediaLoader loader;
  final VoidCallback? onLongPress;

  /// Shown above incoming messages in groups.
  final String? senderName;

  /// Display name of the quoted message's sender ("أنت" for own).
  final String? replySenderName;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.loader,
    this.onLongPress,
    this.senderName,
    this.replySenderName,
  });

  @override
  Widget build(BuildContext context) {
    final media = message.visibleMedia;
    final reactions = message.deleted
        ? const <(ChatReaction, int)>[]
        : message.reactionSummary;
    final footer = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (reaction, count) in reactions)
          Container(
            key: Key('reaction-${message.id}-${reaction.name}'),
            margin: const EdgeInsetsDirectional.only(end: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              count > 1 ? '${reaction.emoji} $count' : reaction.emoji,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        if (message.isEdited) ...[
          Text('تم التعديل', style: _metaStyle),
          const SizedBox(width: 6),
        ],
        Text(formatTimeHm12Ar(message.sentAt), style: _metaStyle),
      ],
    );
    final name = senderName?.trim() ?? '';
    final header = name.isEmpty || isMine
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              name,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
    final reply = message.replyTo;
    final quote = reply == null || message.deleted
        ? null
        : _ReplyQuote(
            reply: reply,
            senderName: replySenderName,
            isMine: isMine,
          );

    if (message.deleted) {
      return _BubbleFrame(
        isMine: isMine,
        footer: footer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ?header,
            Text(
              'تم حذف هذه الرسالة',
              style: _bodyStyle(isMine).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    final Widget? mediaView = media == null
        ? null
        : switch (message.type) {
            ChatMessageType.image => ChatImageView(
              media: media,
              loader: loader,
            ),
            ChatMessageType.voice => ChatVoiceView(
              media: media,
              loader: loader,
              isMine: isMine,
            ),
            ChatMessageType.file => ChatFileView(
              media: media,
              loader: loader,
              isMine: isMine,
            ),
            ChatMessageType.text => null,
          };

    final caption = message.text.trim();
    return _BubbleFrame(
      isMine: isMine,
      footer: footer,
      onLongPress: onLongPress,
      tight: message.type == ChatMessageType.image &&
          mediaView != null &&
          header == null &&
          quote == null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?header,
          ?quote,
          if (mediaView != null) mediaView,
          if (mediaView == null && message.type != ChatMessageType.text)
            Text(
              'المرفق غير متاح',
              style: _bodyStyle(isMine).copyWith(fontStyle: FontStyle.italic),
            ),
          if (caption.isNotEmpty) ...[
            if (mediaView != null) const SizedBox(height: 6),
            Text(caption, style: _bodyStyle(isMine), softWrap: true),
          ],
        ],
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  final ChatReplyEntity reply;
  final String? senderName;
  final bool isMine;

  const _ReplyQuote({
    required this.reply,
    required this.senderName,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isMine ? AppColors.onPrimary : AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: (isMine ? Colors.white : AppColors.primaryLight).withValues(
          alpha: isMine ? 0.18 : 0.7,
        ),
        borderRadius: BorderRadius.circular(8),
        border: BorderDirectional(
          start: BorderSide(
            color: isMine ? AppColors.onPrimary : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((senderName ?? '').isNotEmpty)
            Text(
              senderName!,
              style: AppTextStyles.labelSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          Text(
            reply.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// A message still in the local outbox (uploading / sending / failed).
class ChatOutgoingBubble extends StatelessWidget {
  final ChatOutgoingMessage item;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const ChatOutgoingBubble({
    super.key,
    required this.item,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final failed = item.status == ChatOutgoingStatus.failed;
    final uploading = item.status == ChatOutgoingStatus.uploading;
    final percent = (item.progress * 100).clamp(0, 100).round();

    final status = switch (item.status) {
      ChatOutgoingStatus.uploading => 'جارٍ الرفع $percent٪',
      ChatOutgoingStatus.sending || ChatOutgoingStatus.sent => 'جارٍ الإرسال…',
      ChatOutgoingStatus.failed => item.error ?? 'تعذر الإرسال',
    };

    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status,
          style: _metaStyle.copyWith(
            color: failed ? AppColors.error : AppColors.textHint,
          ),
          textAlign: TextAlign.right,
        ),
        if (item.canRetry || item.canCancel)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.canRetry)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('إعادة المحاولة'),
                ),
              if (item.canCancel)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: Text(uploading ? 'إلغاء الرفع' : 'حذف'),
                ),
            ],
          ),
      ],
    );

    return Opacity(
      opacity: failed ? 1 : 0.85,
      child: _BubbleFrame(
        isMine: true,
        footer: footer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OutgoingContent(item: item),
            if (uploading) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 180,
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 3,
                  color: AppColors.onPrimary,
                  backgroundColor: AppColors.onPrimary.withValues(alpha: 0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutgoingContent extends StatelessWidget {
  final ChatOutgoingMessage item;

  const _OutgoingContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final draft = item.attachment;
    if (draft == null) {
      return Text(item.text, style: _bodyStyle(true), softWrap: true);
    }
    if (draft.type == ChatMessageType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(draft.localPath),
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const _OutgoingLabel(icon: Icons.image_outlined, label: 'صورة'),
        ),
      );
    }
    if (draft.type == ChatMessageType.voice) {
      final d = Duration(milliseconds: draft.durationMs ?? 0);
      return _OutgoingLabel(
        icon: Icons.mic_rounded,
        label: 'رسالة صوتية • ${formatDurationMmSs(d)}',
      );
    }
    return _OutgoingLabel(
      icon: Icons.description_rounded,
      label: '${draft.fileName} • ${formatChatFileSize(draft.sizeBytes)}',
    );
  }
}

class _OutgoingLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OutgoingLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.onPrimary, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(true),
          ),
        ),
      ],
    );
  }
}
