import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../teacher/presentation/widgets/teacher_loading_skeletons.dart';
import '../../domain/entities/posts_entities.dart';
import '../../domain/post_audience_target.dart';
import '../bloc/posts_bloc.dart';
import '../bloc/posts_event.dart';
import '../bloc/posts_state.dart';

/// Teacher Home «المنشورات» tab — uses app-scoped [PostsBloc] (do not close it).
class PostsListPage extends StatefulWidget {
  final String? halaqaId;

  /// When true, render body only (no route AppBar) for Class Details tabs.
  final bool embedded;

  const PostsListPage({
    super.key,
    this.halaqaId,
    this.embedded = false,
  });

  @override
  State<PostsListPage> createState() => _PostsListPageState();
}

class _PostsListPageState extends State<PostsListPage> {
  late final PostsBloc _bloc;
  final _messageController = TextEditingController();
  final List<File> _selectedFiles = [];
  final List<AttachmentType> _selectedTypes = [];
  String _currentUid = '';
  String _currentUserName = '';

  String? get _watchHalaqaId => normalizePostsWatchHalaqaId(widget.halaqaId);

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUid = authState.user.uid;
      _currentUserName = authState.user.name;
    }
    _bloc = sl<PostsBloc>();
    _messageController.addListener(() {
      if (mounted) setState(() {});
    });
    _startWatch();
  }

  @override
  void didUpdateWidget(covariant PostsListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (normalizePostsWatchHalaqaId(oldWidget.halaqaId) != _watchHalaqaId) {
      _startWatch();
    }
  }

  void _startWatch() {
    final halaqaId = _watchHalaqaId;
    if (halaqaId == null) {
      _bloc.add(const WatchPostsEvent(''));
      return;
    }
    _bloc.add(WatchPostsEvent(halaqaId));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (_bloc.state.createPostStatus == SubmissionStatus.submitting) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'mp3', 'wav', 'mp4', 'png', 'jpg', 'jpeg'],
      allowMultiple: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final ext = file.extension?.toLowerCase() ?? '';
      final AttachmentType? type = switch (ext) {
        'pdf' => AttachmentType.pdf,
        'mp3' || 'wav' => AttachmentType.audio,
        'mp4' => AttachmentType.video,
        'png' || 'jpg' || 'jpeg' => AttachmentType.image,
        _ => null,
      };
      if (type == null) continue;
      setState(() {
        _selectedFiles.add(File(path));
        _selectedTypes.add(type);
      });
    }
  }

  void _removeFile(int index) {
    if (_bloc.state.createPostStatus == SubmissionStatus.submitting) return;
    setState(() {
      _selectedFiles.removeAt(index);
      _selectedTypes.removeAt(index);
    });
  }

  void _clearComposer() {
    _messageController.clear();
    setState(() {
      _selectedFiles.clear();
      _selectedTypes.clear();
    });
  }

  bool _canSend(bool submitting) {
    final hasText = _messageController.text.trim().isNotEmpty;
    final hasAttachments = _selectedFiles.isNotEmpty;
    return !submitting &&
        _watchHalaqaId != null &&
        (hasText || hasAttachments);
  }

  void _sendPost() {
    final halaqaId = _watchHalaqaId;
    if (halaqaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد حلقة محددة للمنشورات')),
      );
      return;
    }
    if (!_canSend(
      _bloc.state.createPostStatus == SubmissionStatus.submitting,
    )) {
      return;
    }

    _bloc.add(
      CreatePostEvent(
        authorId: _currentUid,
        authorName: _currentUserName,
        content: _messageController.text,
        halaqaId: halaqaId,
        audience: PostAudience.specificHalaqa,
        attachmentFiles: List<File>.from(_selectedFiles),
        attachmentTypes: List<AttachmentType>.from(_selectedTypes),
      ),
    );
  }

  void _onCreateStatus(PostsState state) {
    if (state.createPostStatus == SubmissionStatus.success) {
      _clearComposer();
      _bloc.add(const ResetCreatePostEvent());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر المنشور بنجاح')),
      );
    } else if (state.createPostStatus == SubmissionStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.createPostError ?? 'فشل النشر')),
      );
      _bloc.add(const ResetCreatePostEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<PostsBloc, PostsState>(
        listenWhen: (previous, current) =>
            previous.createPostStatus != current.createPostStatus,
        listener: (context, state) => _onCreateStatus(state),
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: widget.embedded
              ? null
              : AppBar(title: const Text('المنشورات')),
          body: Column(
            children: [
              if (widget.embedded)
                Material(
                  color: AppColors.surface,
                  child: ListTile(
                    title: Text(
                      'المنشورات',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: BlocBuilder<PostsBloc, PostsState>(
                  buildWhen: (previous, current) =>
                      previous.postsStatus != current.postsStatus ||
                      previous.posts != current.posts ||
                      previous.postsError != current.postsError,
                  builder: (context, state) {
                    if (state.postsStatus == SectionStatus.error) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              state.postsError ?? 'حدث خطأ',
                              style: AppTextStyles.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _startWatch,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (state.postsStatus == SectionStatus.loading &&
                        state.posts.isEmpty) {
                      return const TeacherPostsListSkeleton();
                    }
                    if (state.posts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.post_add_outlined,
                              size: 64,
                              color: AppColors.textHint.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد منشورات بعد',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSizes.paddingM),
                      itemCount: state.posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final post = state.posts[index];
                        return _PostItem(
                          post: post,
                          currentUid: _currentUid,
                          onLike: () => _bloc.add(
                            ToggleLikeEvent(
                              postId: post.id,
                              uid: _currentUid,
                              isCurrentlyLiked: post.isLikedBy(_currentUid),
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailPage(
                                post: post,
                                currentUid: _currentUid,
                                currentUserName: _currentUserName,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              BlocBuilder<PostsBloc, PostsState>(
                buildWhen: (previous, current) =>
                    previous.createPostStatus != current.createPostStatus,
                builder: (context, state) {
                  final submitting =
                      state.createPostStatus == SubmissionStatus.submitting;
                  return _PostsComposerBar(
                    messageController: _messageController,
                    selectedFiles: _selectedFiles,
                    selectedTypes: _selectedTypes,
                    submitting: submitting,
                    canSend: _canSend(submitting),
                    onPickFiles: _pickFiles,
                    onRemoveFile: _removeFile,
                    onSend: _sendPost,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostsComposerBar extends StatelessWidget {
  final TextEditingController messageController;
  final List<File> selectedFiles;
  final List<AttachmentType> selectedTypes;
  final bool submitting;
  final bool canSend;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemoveFile;
  final VoidCallback onSend;

  const _PostsComposerBar({
    required this.messageController,
    required this.selectedFiles,
    required this.selectedTypes,
    required this.submitting,
    required this.canSend,
    required this.onPickFiles,
    required this.onRemoveFile,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selectedFiles.isNotEmpty) ...[
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedFiles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final file = selectedFiles[index];
                      final type = selectedTypes[index];
                      final color = switch (type) {
                        AttachmentType.pdf => AppColors.error,
                        AttachmentType.audio => AppColors.primary,
                        AttachmentType.video => AppColors.secondary,
                        AttachmentType.image => AppColors.success,
                      };
                      final icon = switch (type) {
                        AttachmentType.pdf => Icons.picture_as_pdf_rounded,
                        AttachmentType.audio => Icons.audiotrack_rounded,
                        AttachmentType.video => Icons.play_circle_rounded,
                        AttachmentType.image => Icons.image_rounded,
                      };
                      final name = file.path.split(RegExp(r'[\\/]')).last;
                      return Chip(
                        avatar: Icon(icon, color: color, size: 16),
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: submitting ? null : () => onRemoveFile(index),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: submitting ? null : onPickFiles,
                    icon: const Icon(Icons.attach_file_rounded),
                    color: AppColors.primary,
                    tooltip: 'إرفاق',
                  ),
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      enabled: !submitting,
                      minLines: 1,
                      maxLines: 4,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'اكتب منشوراً...',
                        filled: true,
                        fillColor: AppColors.surfaceGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (canSend) onSend();
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: canSend ? onSend : null,
                    icon: submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: canSend
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                    tooltip: 'إرسال',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostItem extends StatelessWidget {
  final PostEntity post;
  final String currentUid;
  final VoidCallback onLike;
  final VoidCallback onTap;

  const _PostItem({
    required this.post,
    required this.currentUid,
    required this.onLike,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateTime(post.createdAt),
                style: AppTextStyles.labelSmall,
              ),
              Row(
                children: [
                  UserAvatar(
                    name: post.authorName,
                    imageUrl: post.authorImageUrl,
                    size: 36,
                  ),
                  const SizedBox(width: 8),
                  Text(post.authorName, style: AppTextStyles.titleMedium),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (post.isPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'مثبت',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.right,
          ),
          if (post.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.attachments
                  .map((attachment) => _AttachmentItem(attachment: attachment))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    '${post.commentsCount}',
                    style: AppTextStyles.labelSmall,
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.comment_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(width: 24),
              InkWell(
                onTap: onLike,
                child: Row(
                  children: [
                    Text('${post.likesCount}', style: AppTextStyles.labelSmall),
                    const SizedBox(width: 4),
                    Icon(
                      post.isLikedBy(currentUid)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: post.isLikedBy(currentUid)
                          ? AppColors.error
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'منذ ${diff.inMinutes} دقيقة';
      }
      return 'منذ ${diff.inHours} ساعة';
    }
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _AttachmentItem extends StatelessWidget {
  final PostAttachmentEntity attachment;

  const _AttachmentItem({required this.attachment});

  Color get _color => switch (attachment.type) {
    AttachmentType.pdf => AppColors.error,
    AttachmentType.audio => AppColors.primary,
    AttachmentType.video => AppColors.secondary,
    AttachmentType.image => AppColors.success,
  };

  IconData get _icon => switch (attachment.type) {
    AttachmentType.pdf => Icons.picture_as_pdf_rounded,
    AttachmentType.audio => Icons.audiotrack_rounded,
    AttachmentType.video => Icons.play_circle_rounded,
    AttachmentType.image => Icons.image_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(attachment.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(attachment.fileName, style: AppTextStyles.labelMedium),
            const SizedBox(width: 6),
            Icon(_icon, color: _color, size: 20),
          ],
        ),
      ),
    );
  }
}

class PostDetailPage extends StatefulWidget {
  final PostEntity post;
  final String currentUid;
  final String currentUserName;

  const PostDetailPage({
    super.key,
    required this.post,
    required this.currentUid,
    required this.currentUserName,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final PostsBloc _bloc;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bloc = sl<PostsBloc>();
    _bloc.add(WatchCommentsEvent(widget.post.id));
  }

  @override
  void dispose() {
    _commentController.dispose();
    // PostsBloc is a GetIt singleton — never close it from a page.
    super.dispose();
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _bloc.add(
      AddCommentEvent(
        postId: widget.post.id,
        authorId: widget.currentUid,
        authorName: widget.currentUserName,
        content: text,
      ),
    );
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('التفاصيل')),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PostItem(
                      post: widget.post,
                      currentUid: widget.currentUid,
                      onLike: () => _bloc.add(
                        ToggleLikeEvent(
                          postId: widget.post.id,
                          uid: widget.currentUid,
                          isCurrentlyLiked: widget.post.isLikedBy(
                            widget.currentUid,
                          ),
                        ),
                      ),
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'التعليقات'),
                    const SizedBox(height: 12),
                    BlocBuilder<PostsBloc, PostsState>(
                      buildWhen: (previous, current) =>
                          previous.commentsStatus != current.commentsStatus ||
                          previous.comments != current.comments ||
                          previous.commentsError != current.commentsError,
                      builder: (context, state) {
                        if (state.commentsStatus == SectionStatus.loading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (state.comments.isEmpty) {
                          return Center(
                            child: Text(
                              'لا توجد تعليقات',
                              style: AppTextStyles.bodyMedium,
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.comments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final comment = state.comments[index];
                            return AppCard(
                              padding: const EdgeInsets.all(AppSizes.paddingM),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatCommentTime(comment.createdAt),
                                        style: AppTextStyles.labelSmall,
                                      ),
                                      Row(
                                        children: [
                                          UserAvatar(
                                            name: comment.authorName,
                                            imageUrl: comment.authorImageUrl,
                                            size: 32,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            comment.authorName,
                                            style: AppTextStyles.titleMedium,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    comment.content,
                                    style: AppTextStyles.bodyMedium,
                                    textAlign: TextAlign.right,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingM,
                  vertical: 8,
                ),
                color: AppColors.surface,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: _addComment,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'اكتب تعليقاً...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        textAlign: TextAlign.right,
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCommentTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'منذ ${diff.inMinutes} دقيقة';
      }
      return 'منذ ${diff.inHours} ساعة';
    }
    return '${dt.day}/${dt.month}';
  }
}
