import 'dart:async';
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
import '../../domain/entities/posts_entities.dart';
import '../bloc/posts_bloc.dart';
import '../bloc/posts_event.dart';
import '../bloc/posts_state.dart';

/// Teacher Home «المنشورات» tab — uses app-scoped [PostsBloc] (do not close it).
class PostsListPage extends StatefulWidget {
  final String? halaqaId;

  const PostsListPage({super.key, this.halaqaId});

  @override
  State<PostsListPage> createState() => _PostsListPageState();
}

class _PostsListPageState extends State<PostsListPage> {
  late final PostsBloc _bloc;
  String _currentUid = '';
  String _currentUserName = '';
  Timer? _loadingFallback;
  bool _allowEmptyWhileLoading = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUid = authState.user.uid;
      _currentUserName = authState.user.name;
    }
    _bloc = sl<PostsBloc>();
    _bloc.add(WatchPostsEvent(widget.halaqaId ?? 'general'));
    // If Firestore never emits, fall back to empty state instead of spinning forever.
    _loadingFallback = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      final s = _bloc.state;
      if (s.postsStatus == SectionStatus.loading && s.posts.isEmpty) {
        setState(() => _allowEmptyWhileLoading = true);
      }
    });
  }

  @override
  void dispose() {
    _loadingFallback?.cancel();
    super.dispose();
  }

  Future<void> _navigateToCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostPage(
          halaqaId: widget.halaqaId,
          currentUserName: _currentUserName,
          currentUid: _currentUid,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم نشر المنشور بنجاح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('المنشورات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _navigateToCreatePost,
            ),
          ],
        ),
        body: BlocBuilder<PostsBloc, PostsState>(
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
                      onPressed: () => _bloc.add(
                        WatchPostsEvent(widget.halaqaId ?? 'general'),
                      ),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }
            // Avoid endless spinner: show empty when nothing to show yet.
            if (state.posts.isEmpty) {
              if (state.postsStatus == SectionStatus.loading &&
                  !_allowEmptyWhileLoading) {
                return const AppLoadingWidget();
              }
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
          // Header: author and time
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

class CreatePostPage extends StatefulWidget {
  final String? halaqaId;
  final String currentUserName;
  final String currentUid;

  const CreatePostPage({
    super.key,
    required this.halaqaId,
    required this.currentUserName,
    required this.currentUid,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  final List<File> _selectedFiles = [];
  final List<AttachmentType> _selectedTypes = [];
  PostAudience _audience = PostAudience.specificHalaqa;
  bool _isSubmitting = false;

  Future<void> _pickFiles() async {
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
      AttachmentType type;
      switch (ext) {
        case 'pdf':
          type = AttachmentType.pdf;
          break;
        case 'mp3':
        case 'wav':
          type = AttachmentType.audio;
          break;
        case 'mp4':
          type = AttachmentType.video;
          break;
        case 'png':
        case 'jpg':
        case 'jpeg':
          type = AttachmentType.image;
          break;
        default:
          continue;
      }
      setState(() {
        _selectedFiles.add(File(path));
        _selectedTypes.add(type);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      _selectedTypes.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() {
      _isSubmitting = true;
    });

    final bloc = sl<PostsBloc>();
    bloc.add(
      CreatePostEvent(
        authorId: widget.currentUid,
        authorName: widget.currentUserName,
        content: _contentController.text,
        halaqaId: widget.halaqaId,
        audience: _audience,
        attachmentFiles: _selectedFiles,
        attachmentTypes: _selectedTypes,
      ),
    );

    await Future.doWhile(
      () => Future.delayed(const Duration(milliseconds: 100), () {
        return bloc.state.createPostStatus == SubmissionStatus.submitting;
      }),
    );

    if (!mounted) return;
    if (bloc.state.createPostStatus == SubmissionStatus.success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bloc.state.createPostError ?? 'فشل النشر')),
      );
    }
    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('نشر منشور'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: const Text('نشر'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _contentController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'اكتب شيئاً...',
                border: InputBorder.none,
              ),
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 20),
            if (_selectedFiles.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_selectedFiles.length, (index) {
                  final file = _selectedFiles[index];
                  final type = _selectedTypes[index];
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
                  return Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: color, size: 18),
                        const SizedBox(width: 6),
                        Text(file.path.split('/').last),
                      ],
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeFile(index),
                  );
                }),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<PostAudience>(
                    segments: const [
                      ButtonSegment(
                        value: PostAudience.specificHalaqa,
                        label: Text('الحلقة'),
                      ),
                      ButtonSegment(
                        value: PostAudience.allHalaqat,
                        label: Text('الجميع'),
                      ),
                    ],
                    selected: {_audience},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _audience = selection.first;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('إرفاق'),
                ),
              ],
            ),
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
