import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/chat_groups_repository.dart';
import '../../domain/entities/chat_entities.dart';
import '../media/chat_media_loader.dart';
import '../widgets/chat_media_views.dart';
import '../widgets/chat_person_search.dart';

final _linkPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);

/// First http(s) link in [text], or null.
String? firstChatLink(String text) => _linkPattern.firstMatch(text)?.group(0);

/// Group details for members: name, image, description, members, and the
/// media / documents / links shared in the group. Admin manages custom groups
/// (name, image, members); halaqa groups follow the halaqa roster.
class ChatGroupInfoPage extends StatefulWidget {
  final String conversationId;
  final String viewerUid;
  final String viewerRole;
  final ChatGroupsRepository repository;
  final ChatMediaLoader loader;

  const ChatGroupInfoPage({
    super.key,
    required this.conversationId,
    required this.viewerUid,
    required this.viewerRole,
    required this.repository,
    required this.loader,
  });

  @override
  State<ChatGroupInfoPage> createState() => _ChatGroupInfoPageState();
}

class _ChatGroupInfoPageState extends State<ChatGroupInfoPage> {
  late final Stream<ConversationEntity?> _conversation = widget.repository
      .watchConversation(widget.conversationId, viewerUid: widget.viewerUid);
  bool _busy = false;

  bool _canManage(ConversationEntity c) =>
      widget.viewerRole == AppRoles.admin && c.isCustomGroup;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) AppSnackBar.showSuccess(context, done);
    } on ServerException catch (e) {
      if (mounted) AppSnackBar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(ConversationEntity c) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _EditGroupDialog(
        title: c.title ?? '',
        description: c.description ?? '',
      ),
    );
    if (result == null) return;
    await _run(
      () => widget.repository.updateGroup(
        conversationId: c.id,
        title: result.$1,
        description: result.$2,
      ),
      'تم تحديث بيانات المجموعة',
    );
  }

  Future<void> _changeImage(ConversationEntity c) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    await _run(
      () => widget.repository.uploadGroupImage(
        conversationId: c.id,
        bytes: bytes,
        extension: file.extension ?? '',
      ),
      'تم تحديث صورة المجموعة',
    );
  }

  Future<void> _addMembers(ConversationEntity c) async {
    final existing = {for (final p in c.participants) p.uid};
    final ids = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddMembersSheet(
        existing: existing,
        search: (q) =>
            widget.repository.searchPeople(q, excludeUid: widget.viewerUid),
      ),
    );
    if (ids == null || ids.isEmpty) return;
    await _run(
      () => widget.repository.setMembers(conversationId: c.id, add: ids),
      'تمت إضافة الأعضاء',
    );
  }

  Future<void> _remove(ConversationEntity c, ChatParticipantEntity p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة عضو'),
        content: Text(
          'سيفقد ${p.name} الوصول إلى المجموعة ورسائلها وملفاتها فوراً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            key: const Key('confirm-remove-member'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => widget.repository.setMembers(conversationId: c.id, remove: [p.uid]),
      'تمت إزالة العضو',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<ConversationEntity?>(
        stream: _conversation,
        builder: (context, snap) {
          final c = snap.data;
          if (snap.hasError || (snap.connectionState == ConnectionState.active && c == null)) {
            return Scaffold(
              appBar: AppBar(title: const Text('معلومات المجموعة')),
              body: const Center(
                child: Text('لم يعد لديك وصول إلى هذه المجموعة'),
              ),
            );
          }
          if (c == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('معلومات المجموعة')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          return _buildGroup(c);
        },
      ),
    );
  }

  Widget _buildGroup(ConversationEntity c) {
    final manage = _canManage(c);
    final members = [...c.participants]
      ..sort((a, b) => a.name.compareTo(b.name));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('معلومات المجموعة'),
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(minHeight: 3),
                )
              : null,
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _GroupAvatar(
                      imagePath: c.imagePath,
                      title: c.displayTitle(widget.viewerUid),
                      repository: widget.repository,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c.displayTitle(widget.viewerUid),
                      key: const Key('group-info-title'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'مجموعة · ${members.length} عضو',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if ((c.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        c.description!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                    if (c.kind == ConversationKinds.halaqaGroup) ...[
                      const SizedBox(height: 8),
                      Text(
                        'أعضاء مجموعة الحلقة يتحدّثون تلقائياً مع قائمة الحلقة.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                    if (manage) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('group-edit'),
                            onPressed: _busy ? null : () => _edit(c),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('تعديل الاسم والوصف'),
                          ),
                          OutlinedButton.icon(
                            key: const Key('group-image'),
                            onPressed: _busy ? null : () => _changeImage(c),
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('تغيير الصورة'),
                          ),
                          FilledButton.icon(
                            key: const Key('group-add-members'),
                            onPressed: _busy ? null : () => _addMembers(c),
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('إضافة أعضاء'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'الأعضاء',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: members.length,
              itemBuilder: (context, i) {
                final p = members[i];
                final isGroupAdmin = c.groupAdminIds.contains(p.uid);
                return ListTile(
                  key: Key('group-member-${p.uid}'),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      p.name.trim().isEmpty ? '؟' : p.name.trim()[0],
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
                  title: Text(p.uid == widget.viewerUid ? 'أنت' : p.name),
                  subtitle: Text(
                    isGroupAdmin
                        ? '${chatRoleLabel(p.role)} · مسؤول المجموعة'
                        : chatRoleLabel(p.role),
                  ),
                  trailing: manage && p.uid != widget.viewerUid
                      ? IconButton(
                          key: Key('remove-member-${p.uid}'),
                          tooltip: 'إزالة من المجموعة',
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            color: AppColors.error,
                          ),
                          onPressed: _busy ? null : () => _remove(c, p),
                        )
                      : null,
                );
              },
            ),
            const SliverToBoxAdapter(
              child: TabBar(
                tabs: [
                  Tab(text: 'الوسائط'),
                  Tab(text: 'المستندات'),
                  Tab(text: 'الروابط'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              for (final tab in ChatGroupLibraryTab.values)
                _LibraryTab(
                  key: PageStorageKey('library-${tab.name}'),
                  conversationId: c.id,
                  tab: tab,
                  repository: widget.repository,
                  loader: widget.loader,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupAvatar extends StatefulWidget {
  final String? imagePath;
  final String title;
  final ChatGroupsRepository repository;

  const _GroupAvatar({
    required this.imagePath,
    required this.title,
    required this.repository,
  });

  @override
  State<_GroupAvatar> createState() => _GroupAvatarState();
}

class _GroupAvatarState extends State<_GroupAvatar> {
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _GroupAvatar old) {
    super.didUpdateWidget(old);
    if (old.imagePath != widget.imagePath) _load();
  }

  void _load() {
    final path = widget.imagePath;
    _bytes = path == null ? null : widget.repository.groupImageBytes(path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        final bytes = snap.data;
        return CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: bytes == null ? null : MemoryImage(bytes),
          child: bytes == null
              ? const Icon(Icons.groups_rounded, size: 40, color: AppColors.primary)
              : null,
        );
      },
    );
  }
}

class _LibraryTab extends StatefulWidget {
  final String conversationId;
  final ChatGroupLibraryTab tab;
  final ChatGroupsRepository repository;
  final ChatMediaLoader loader;

  const _LibraryTab({
    super.key,
    required this.conversationId,
    required this.tab,
    required this.repository,
    required this.loader,
  });

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab>
    with AutomaticKeepAliveClientMixin {
  final List<MessageEntity> _items = [];
  DocumentSnapshot? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.libraryPage(
        widget.conversationId,
        widget.tab,
        after: _cursor,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on ServerException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  String get _emptyLabel => switch (widget.tab) {
    ChatGroupLibraryTab.media => 'لا توجد صور مشتركة بعد',
    ChatGroupLibraryTab.documents => 'لا توجد مستندات مشتركة بعد',
    ChatGroupLibraryTab.links => 'لا توجد روابط مشتركة بعد',
  };

  Widget _item(MessageEntity m) {
    final media = m.visibleMedia;
    final date = formatTimeHm12Ar(m.sentAt);
    switch (widget.tab) {
      case ChatGroupLibraryTab.media:
        if (media == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChatImageView(media: media, loader: widget.loader),
        );
      case ChatGroupLibraryTab.documents:
        if (media == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatFileView(media: media, loader: widget.loader, isMine: false),
        );
      case ChatGroupLibraryTab.links:
        final link = firstChatLink(m.text);
        if (link == null) return const SizedBox.shrink();
        return ListTile(
          leading: const Icon(Icons.link_rounded, color: AppColors.primary),
          title: Text(
            link,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
          ),
          subtitle: Text(date),
          onTap: () async {
            final uri = Uri.tryParse(link);
            if (uri == null) return;
            final opened = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (!opened && mounted) {
              AppSnackBar.showError(context, 'تعذر فتح الرابط');
            }
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadMore);
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _emptyLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final m in _items) _item(m),
        if (_hasMore)
          Center(
            child: _loading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : TextButton(
                    onPressed: _loadMore,
                    child: const Text('عرض المزيد'),
                  ),
          ),
      ],
    );
  }
}

class _EditGroupDialog extends StatefulWidget {
  final String title;
  final String description;

  const _EditGroupDialog({required this.title, required this.description});

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late final _title = TextEditingController(text: widget.title);
  late final _description = TextEditingController(text: widget.description);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('بيانات المجموعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('group-edit-title'),
              controller: _title,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'اسم المجموعة'),
            ),
            TextField(
              controller: _description,
              maxLength: 500,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _title,
            builder: (context, value, _) => TextButton(
              onPressed: value.text.trim().length < 2
                  ? null
                  : () => Navigator.pop(
                      context,
                      (value.text.trim(), _description.text.trim()),
                    ),
              child: const Text('حفظ'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMembersSheet extends StatefulWidget {
  final Set<String> existing;
  final ChatPeopleSearch search;

  const _AddMembersSheet({required this.existing, required this.search});

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final Map<String, String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إضافة أعضاء',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ChatPersonSearch(
                search: widget.search,
                selected: _selected.keys.toSet(),
                disabled: widget.existing,
                onTap: (hit) => setState(() {
                  if (_selected.remove(hit.uid) == null) {
                    _selected[hit.uid] = hit.name;
                  }
                }),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('add-members-confirm'),
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.keys.toList()),
                child: Text('إضافة (${_selected.length})'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
