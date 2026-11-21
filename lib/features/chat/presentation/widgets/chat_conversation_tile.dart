import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../domain/entities/chat_entities.dart';
import 'chat_person_search.dart';

/// `10:30 م` today, `أمس`, otherwise `d/m/yyyy`.
String chatListTimeLabel(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  if (day == today) return formatTimeHm12Ar(at);
  if (day == today.subtract(const Duration(days: 1))) return 'أمس';
  return '${at.day}/${at.month}/${at.year}';
}

/// Last-message line: `أنت: …` for own messages, `الاسم: …` in groups.
String chatListPreview(ConversationEntity c, String viewerUid) {
  final text = c.lastMessage?.trim() ?? '';
  if (text.isEmpty) {
    return c.isGroup ? '${c.participants.length} عضو' : 'لا رسائل بعد';
  }
  final sender = c.lastMessageSenderId;
  if (sender == null || sender.isEmpty) return text;
  if (sender == viewerUid) return 'أنت: $text';
  if (c.isGroup) {
    final name = c.participantName(sender);
    if (name != null) return '$name: $text';
  }
  return text;
}

/// Inbox row. [observer] marks Admin oversight of a thread they are not in.
class ChatConversationTile extends StatelessWidget {
  final ConversationEntity conversation;
  final String viewerUid;
  final bool observer;
  final VoidCallback onTap;

  const ChatConversationTile({
    super.key,
    required this.conversation,
    required this.viewerUid,
    required this.onTap,
    this.observer = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final title = c.displayTitleForObserver(viewerUid);
    final unread = observer ? 0 : c.unreadCount;
    final subtitle = observer && !c.isGroup
        ? c.participants.map((p) => chatRoleLabel(p.role)).join(' · ')
        : null;
    final peerImage = !c.isGroup && !observer
        ? c.otherParticipant(viewerUid).profileImageUrl
        : null;
    return Material(
      color: unread > 0
          ? AppColors.primary.withValues(alpha: 0.05)
          : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primaryLight,
          backgroundImage:
              peerImage != null && peerImage.isNotEmpty
              ? NetworkImage(peerImage)
              : null,
          child: peerImage != null && peerImage.isNotEmpty
              ? null
              : c.isGroup
              ? const Icon(Icons.groups_rounded, color: AppColors.primary)
              : Text(
                  title.trim().isEmpty ? '؟' : title.trim().characters.first,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              chatListTimeLabel(c.lastMessageAt),
              style: AppTextStyles.labelSmall.copyWith(
                color: unread > 0 ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                subtitle == null
                    ? chatListPreview(c, viewerUid)
                    : '$subtitle · ${chatListPreview(c, viewerUid)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (observer)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: Text(
                  'مراقبة',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (unread > 0)
              Container(
                margin: const EdgeInsetsDirectional.only(start: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
