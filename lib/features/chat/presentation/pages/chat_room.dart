import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/error/exception.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/chat_groups_repository.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/policies/chat_media_policy.dart';
import '../chat_groups_provider.dart';
import 'chat_group_info_page.dart';
import '../bloc/chat_conversations_bloc.dart';
import '../bloc/chat_conversations_state.dart';
import '../bloc/chat_room_bloc.dart';
import '../bloc/chat_room_event.dart';
import '../bloc/chat_room_state.dart';
import '../chat_message_alignment.dart';
import '../media/chat_media_loader.dart';
import '../media/chat_voice_recorder.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_message_bubble.dart';

/// Shared chat room (1:1 and Halaqa group) — Teacher, Student, Parent,
/// Supervisor and Admin routes. Text, image, voice and PDF/Word messages;
/// sends go through `sendChatMessage`, history is paged newest-first.
class ChatRoomPage extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserImage;

  /// Test seams; production resolves these from DI / plugins.
  final ChatRoomBloc? bloc;
  final ChatMediaLoader? mediaLoader;
  final ChatVoiceRecorder Function()? recorderFactory;
  final ChatAttachmentPicker? pickAttachment;

  /// Silent oversight: hide composer; do not join as participant.
  final bool readOnly;

  /// Group metadata, reactions and group info (test seam; production builds
  /// one from the registered Firebase singletons).
  final ChatGroupsRepository? groups;

  /// Viewer role when [bloc] is injected (tests); otherwise from [AuthBloc].
  final String? viewerRole;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserImage,
    this.bloc,
    this.mediaLoader,
    this.recorderFactory,
    this.pickAttachment,
    this.readOnly = false,
    this.groups,
    this.viewerRole,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final ChatRoomBloc _chatBloc;
  late final ChatMediaLoader _loader;
  String _currentUid = '';
  String _role = '';
  ChatGroupsRepository? _groups;
  StreamSubscription<ConversationEntity?>? _metaSub;
  ConversationEntity? _meta;
  MessageEntity? _replyTo;

  @override
  void initState() {
    super.initState();
    final injected = widget.bloc;
    _role = widget.viewerRole ?? '';
    if (injected != null) {
      _chatBloc = injected;
      _currentUid = injected.currentUserId;
    } else {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _currentUid = authState.user.uid;
        _role = authState.user.role;
      }
      _chatBloc = sl<ChatRoomBloc>(
        param1: widget.conversationId,
        param2: _currentUid,
      );
    }
    _loader = widget.mediaLoader ?? sl<ChatMediaLoader>();
    _scrollCtrl.addListener(_onScroll);
    _groups = widget.groups ??
        (sl.isRegistered<FirebaseFirestore>() &&
                sl.isRegistered<FirebaseFunctions>() &&
                sl.isRegistered<FirebaseStorage>()
            ? resolveChatGroupsRepository()
            : null);
    _metaSub = _groups
        ?.watchConversation(widget.conversationId, viewerUid: _currentUid)
        .listen((c) {
          if (mounted) setState(() => _meta = c);
        }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _metaSub?.cancel();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _chatBloc.close();
    super.dispose();
  }

  bool get _isAdmin => _role == AppRoles.admin;

  /// "أنت" for own messages; member name from the conversation otherwise.
  String? _nameOf(String uid) {
    if (uid.isEmpty) return null;
    if (uid == _currentUid) return 'أنت';
    return _meta?.participantName(uid);
  }

  static String _previewOf(MessageEntity m) {
    if (m.deleted) return 'تم حذف هذه الرسالة';
    final text = m.text.trim();
    if (text.isNotEmpty) return text;
    return switch (m.type) {
      ChatMessageType.image => 'صورة',
      ChatMessageType.voice => 'رسالة صوتية',
      ChatMessageType.file => m.media?.fileName ?? 'ملف',
      ChatMessageType.text => '',
    };
  }

  Future<void> _react(MessageEntity msg, ChatReaction reaction) async {
    final groups = _groups;
    if (groups == null) return;
    final current = msg.reactions[_currentUid];
    try {
      await groups.react(
        conversationId: widget.conversationId,
        messageId: msg.id,
        reaction: current == reaction ? null : reaction,
      );
    } on ServerException catch (e) {
      if (mounted) AppSnackBar.showError(context, e.message);
    }
  }

  void _openGroupInfo() {
    final groups = _groups;
    if (groups == null || _meta?.isGroup != true) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatGroupInfoPage(
          conversationId: widget.conversationId,
          viewerUid: _currentUid,
          viewerRole: _role,
          repository: groups,
          loader: _loader,
        ),
      ),
    );
  }

  /// List is reversed: offset 0 is the newest message, max extent is history.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      final s = _chatBloc.state;
      if (s.hasMore && !s.loadingOlder) {
        _chatBloc.add(const LoadOlderMessagesRequestedEvent());
      }
    }
  }

  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendText(String text) {
    _chatBloc.add(
      SendMessageRequestedEvent(text, replyToMessageId: _replyTo?.id),
    );
    if (_replyTo != null) setState(() => _replyTo = null);
    _scrollToNewest();
  }

  void _sendAttachment(ChatAttachmentDraft draft) {
    _chatBloc.add(SendAttachmentRequestedEvent(draft));
    _scrollToNewest();
  }

  /// Prefer route `extra`; fall back to denormalized conversation participants.
  (String, String?) _resolvePeer(ChatParticipantEntity? peer) {
    final extraName = widget.otherUserName.trim();
    final peerName = peer?.name.trim() ?? '';
    final name =
        extraName.isNotEmpty && extraName != 'محادثة' && extraName != 'المعلم'
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

  Future<void> _showMessageActions(MessageEntity msg) async {
    final canCopy = !msg.deleted && msg.text.trim().isNotEmpty;
    final canEdit = !widget.readOnly && ChatMediaPolicy.canEdit(msg, _currentUid);
    final canDelete = ChatMediaPolicy.canDelete(
      msg,
      _currentUid,
      isAdmin: _isAdmin,
    );
    final canInteract = !widget.readOnly && !msg.deleted;
    final canReact = canInteract && _groups != null;
    if (!canCopy && !canEdit && !canDelete && !canInteract) return;
    final myReaction = msg.reactions[_currentUid];

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canReact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final r in ChatReaction.values)
                        InkWell(
                          key: Key('react-${r.name}'),
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => Navigator.pop(ctx, 'react:${r.name}'),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: myReaction == r
                                  ? AppColors.primaryLight
                                  : null,
                            ),
                            child: Text(
                              r.emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (canInteract)
                ListTile(
                  key: const Key('action-reply'),
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('رد'),
                  onTap: () => Navigator.pop(ctx, 'reply'),
                ),
              if (canCopy)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('نسخ النص'),
                  onTap: () => Navigator.pop(ctx, 'copy'),
                ),
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('تعديل'),
                  subtitle: const Text('متاح خلال 15 دقيقة من الإرسال'),
                  onTap: () => Navigator.pop(ctx, 'edit'),
                ),
              if (canDelete)
                ListTile(
                  key: const Key('action-delete'),
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'حذف',
                    style: TextStyle(color: AppColors.error),
                  ),
                  subtitle: _isAdmin && !msg.isMine(_currentUid)
                      ? const Text('حذف إداري')
                      : const Text('متاح خلال ساعة من الإرسال'),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action.startsWith('react:')) {
      final reaction = ChatReaction.fromWire(action.substring(6));
      if (reaction != null) await _react(msg, reaction);
      return;
    }
    switch (action) {
      case 'reply':
        setState(() => _replyTo = msg);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: msg.text));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نسخ النص', textAlign: TextAlign.right),
          ),
        );
      case 'edit':
        await _editMessage(msg);
      case 'delete':
        await _confirmDelete(msg);
    }
  }

  Future<void> _editMessage(MessageEntity msg) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _EditMessageDialog(initialText: msg.text),
    );
    if (text == null || text.trim() == msg.text.trim()) return;
    _chatBloc.add(EditMessageRequestedEvent(msg.id, text));
  }

  Future<void> _confirmDelete(MessageEntity msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الرسالة'),
          content: const Text(
            'ستظهر الرسالة للجميع على أنها محذوفة، ولن يتمكن أحد من فتح مرفقها.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      _chatBloc.add(SoftDeleteMessageRequestedEvent(msg.id));
    }
  }

  Widget _header() {
    void back() {
      if (context.canPop()) context.pop();
    }

    final meta = _meta;
    if (meta != null && meta.isGroup) {
      return _ChatRoomHeader(
        name: meta.displayTitle(_currentUid),
        imageUrl: null,
        isGroup: true,
        subtitle: '${meta.participants.length} عضو · اضغط لمعلومات المجموعة',
        onTap: _openGroupInfo,
        onBack: back,
      );
    }

    Widget build(ChatParticipantEntity? peer) {
      final (name, imageUrl) = _resolvePeer(peer);
      return _ChatRoomHeader(name: name, imageUrl: imageUrl, onBack: back);
    }

    if (meta != null && _currentUid.isNotEmpty) {
      return build(meta.otherParticipant(_currentUid));
    }

    if (!sl.isRegistered<ChatConversationsBloc>()) return build(null);
    return BlocBuilder<ChatConversationsBloc, ChatConversationsState>(
      bloc: sl<ChatConversationsBloc>(),
      buildWhen: (p, c) => p.conversations != c.conversations,
      builder: (context, convState) {
        ChatParticipantEntity? peer;
        for (final c in convState.conversations) {
          if (c.id == widget.conversationId && _currentUid.isNotEmpty) {
            peer = c.otherParticipant(_currentUid);
            break;
          }
        }
        return build(peer);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocProvider.value(
        value: _chatBloc,
        child: BlocListener<ChatRoomBloc, ChatRoomState>(
          listenWhen: (p, c) =>
              c.actionError != null && p.actionError != c.actionError,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.actionError!, textAlign: TextAlign.right),
                ),
              );
            _chatBloc.add(const ActionErrorDismissedEvent());
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF5FAFB),
            body: Column(
              children: [
                _header(),
                Expanded(child: _buildMessages()),
                if (widget.readOnly)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    color: AppColors.surface,
                    child: Text(
                      'وضع مراقبة — قراءة فقط',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else ...[
                  if (_replyTo != null)
                    _ReplyBar(
                      senderName: _nameOf(_replyTo!.senderId),
                      preview: _previewOf(_replyTo!),
                      onCancel: () => setState(() => _replyTo = null),
                    ),
                  ChatComposer(
                    controller: _messageCtrl,
                    onSendText: _sendText,
                    onAttachment: _sendAttachment,
                    recorderFactory:
                        widget.recorderFactory ?? RecordChatVoiceRecorder.new,
                    pickAttachment: widget.pickAttachment ?? pickChatAttachment,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return BlocBuilder<ChatRoomBloc, ChatRoomState>(
      buildWhen: (p, c) =>
          p.messages != c.messages ||
          p.messagesStatus != c.messagesStatus ||
          p.messagesError != c.messagesError ||
          p.outbox != c.outbox ||
          p.loadingOlder != c.loadingOlder,
      builder: (context, state) {
        final pending = state.pendingOutbox;
        if (state.messages.isEmpty && pending.isEmpty) {
          if (state.messagesStatus == SectionStatus.loading ||
              state.messagesStatus == SectionStatus.initial) {
            return const _MessagesSkeleton();
          }
          if (state.messagesStatus == SectionStatus.error) {
            return AppErrorWidget(
              message: state.messagesError ?? 'تعذر تحميل الرسائل',
              onRetry: () => _chatBloc.add(const WatchMessagesStartedEvent()),
            );
          }
          return const _EmptyConversation();
        }

        final messages = state.messages;
        final showHistoryRow = state.hasMore || state.loadingOlder;
        final itemCount =
            pending.length + messages.length + (showHistoryRow ? 1 : 0);

        return Column(
          children: [
            if (state.messagesStatus == SectionStatus.error)
              _StreamErrorBanner(
                message: state.messagesError ?? 'تعذر تحديث الرسائل',
                onRetry: () => _chatBloc.add(const WatchMessagesStartedEvent()),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index < pending.length) {
                    final item = pending[pending.length - 1 - index];
                    return ChatOutgoingBubble(
                      key: ValueKey('out_${item.messageId}'),
                      item: item,
                      onRetry: () => _chatBloc.add(
                        RetryOutgoingRequestedEvent(item.messageId),
                      ),
                      onCancel: () => _chatBloc.add(
                        CancelOutgoingRequestedEvent(item.messageId),
                      ),
                    );
                  }
                  final mi = index - pending.length;
                  if (mi >= messages.length) {
                    return _HistoryRow(
                      loading: state.loadingOlder,
                      onLoad: () => _chatBloc.add(
                        const LoadOlderMessagesRequestedEvent(),
                      ),
                    );
                  }
                  final i = messages.length - 1 - mi;
                  final msg = messages[i];
                  final showDate =
                      i == 0 || !_sameDay(messages[i - 1].sentAt, msg.sentAt);
                  return Column(
                    key: ValueKey('msg_${msg.id}'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDate) _DateChip(date: msg.sentAt),
                      ChatMessageBubble(
                        message: msg,
                        isMine: msg.isMine(_currentUid),
                        loader: _loader,
                        senderName: _meta?.isGroup == true
                            ? _nameOf(msg.senderId)
                            : null,
                        replySenderName: msg.replyTo == null
                            ? null
                            : _nameOf(msg.replyTo!.senderId),
                        onLongPress: msg.deleted
                            ? null
                            : () => _showMessageActions(msg),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;
}

// ── Edit dialog ───────────────────────────────────────────────────────────────

class _EditMessageDialog extends StatefulWidget {
  final String initialText;

  const _EditMessageDialog({required this.initialText});

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تعديل الرسالة'),
        content: TextField(
          controller: _ctrl,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          maxLength: ChatMediaPolicy.textMaxChars,
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _ctrl,
            builder: (context, value, _) => TextButton(
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, value.text.trim()),
              child: const Text('حفظ'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ReplyBar extends StatelessWidget {
  final String? senderName;
  final String preview;
  final VoidCallback onCancel;

  const _ReplyBar({
    required this.senderName,
    required this.preview,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('reply-bar'),
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: const BorderDirectional(
            start: BorderSide(color: AppColors.primary, width: 3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName == null ? 'رد على رسالة' : 'رد على $senderName',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall,
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('reply-cancel'),
              tooltip: 'إلغاء الرد',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRoomHeader extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final VoidCallback onBack;
  final bool isGroup;
  final String? subtitle;
  final VoidCallback? onTap;

  const _ChatRoomHeader({
    required this.name,
    required this.imageUrl,
    required this.onBack,
    this.isGroup = false,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
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
          AppBackButton(
            circular: true,
            size: 40,
            color: AppColors.textPrimary,
            onPressed: onBack,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              key: const Key('chat-header'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  isGroup
                      ? const CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.groups_rounded,
                            color: AppColors.primary,
                          ),
                        )
                      : _HeaderAvatar(name: name, imageUrl: imageUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
    final initial = name.trim().isEmpty ? '?' : name.trim()[0];
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

// ── List chrome ───────────────────────────────────────────────────────────────

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 52,
            color: AppColors.textHint.withValues(alpha: 0.45),
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
}

class _StreamErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StreamErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.error.withValues(alpha: 0.1),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final bool loading;
  final VoidCallback onLoad;

  const _HistoryRow({required this.loading, required this.onLoad});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onLoad,
                child: const Text('عرض الرسائل الأقدم'),
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
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.35,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
