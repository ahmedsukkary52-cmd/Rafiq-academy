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
import '../../domain/entities/content_file_entity.dart';
import '../bloc/content_bloc.dart';
import '../bloc/content_event.dart';
import '../bloc/content_state.dart';

class ContentLibraryPage extends StatefulWidget {
  final String? halaqaId;

  const ContentLibraryPage({super.key, this.halaqaId});

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  late final ContentLibraryBloc _bloc;
  String _currentUid = '';
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUid = authState.user.uid;
      _currentUserName = authState.user.name;
    }
    _bloc = sl<ContentLibraryBloc>();
    _bloc.add(LoadFilesEvent(halaqaId: widget.halaqaId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'mp3',
        'wav',
        'mp4',
        'png',
        'jpg',
        'jpeg',
        'doc',
        'docx',
      ],
    );
    if (result == null) return;

    final file = File(result.files.single.path!);
    final fileName = result.files.single.name;

    // Determine file type
    ContentFileType type;
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        type = ContentFileType.pdf;
        break;
      case 'mp3':
      case 'wav':
        type = ContentFileType.audio;
        break;
      case 'mp4':
        type = ContentFileType.video;
        break;
      case 'png':
      case 'jpg':
      case 'jpeg':
        type = ContentFileType.image;
        break;
      case 'doc':
      case 'docx':
      default:
        type = ContentFileType.document;
        break;
    }

    // Show title input dialog
    if (!mounted) return;
    final titleController = TextEditingController(text: fileName);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إرفاق ملف'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'اسم الملف'),
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('رفع'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        _bloc.add(
          UploadFileEvent(
            file: file,
            title: titleController.text,
            type: type,
            uploadedBy: _currentUid,
            uploaderName: _currentUserName,
            halaqaId: widget.halaqaId,
          ),
        );
      }
    } finally {
      titleController.dispose();
    }
  }

  Future<void> _openFile(ContentFileEntity file) async {
    // For image, pdf, etc., try launching the URL
    final uri = Uri.parse(file.downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح الملف')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('مكتبة المحتوى'),
          actions: [
            TextButton.icon(
              onPressed: _pickAndUploadFile,
              icon: const Icon(
                Icons.upload_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                '+ رفع',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        body: BlocBuilder<ContentLibraryBloc, ContentLibraryState>(
          buildWhen: (previous, current) =>
              previous.filesStatus != current.filesStatus ||
              previous.allFiles != current.allFiles ||
              previous.activeFilter != current.activeFilter ||
              previous.filesError != current.filesError,
          builder: (context, state) {
            final files = state.filteredFiles;
            return Column(
              children: [
                // ── بحث ─────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.all(AppSizes.paddingM),
                  child: AppTextField(
                    hint: 'بحث في المكتبة...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.textHint,
                    ),
                  ),
                ),

                // ── فلاتر النوع ───────────────────────────────────
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                    ),
                    reverse: true,
                    children:
                        [
                          null, // الكل
                          ...ContentFileType.values,
                        ].map((type) {
                          final selected = state.activeFilter == type;
                          final label = type?.label ?? 'الكل';
                          return GestureDetector(
                            onTap: () => _bloc.add(FilterFilesEvent(type)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.surface,
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
                                label,
                                style: TextStyle(
                                  fontFamily: 'NotoNaskhArabic',
                                  fontSize: 13,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // ── upload progress (isolated from file list rebuilds) ──
                BlocSelector<ContentLibraryBloc, ContentLibraryState, double?>(
                  selector: (s) => s.uploadProgress,
                  builder: (context, progress) {
                    if (progress == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingM,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'جارٍ الرفع... ${(progress * 100).toInt()}%',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: progress,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),

                // ── الملفات ──────────────────────────────────────
                Expanded(
                  child: state.filesStatus == SectionStatus.loading
                      ? const AppLoadingWidget()
                      : files.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: 64,
                                color: AppColors.textHint.withOpacity(0.4),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا يوجد محتوى متاح حالياً',
                                style: AppTextStyles.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ستظهر هنا الملفات التعليمية عند إضافتها',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textHint,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.paddingM,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: files.length,
                          itemBuilder: (context, i) => _FileCard(
                            file: files[i],
                            onTap: () => _openFile(files[i]),
                          ),
                        ),
                ),

                // ── آخر الرفوعات ──────────────────────────────────
                if (state.allFiles.isNotEmpty) ...[
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.paddingM,
                      8,
                      AppSizes.paddingM,
                      0,
                    ),
                    child: SectionHeader(title: 'آخر الرفوعات'),
                  ),
                  SizedBox(
                    height: 56,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingM,
                        vertical: 8,
                      ),
                      itemCount: state.allFiles.take(3).length,
                      itemBuilder: (context, i) {
                        final file = state.allFiles[i];
                        return Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGrey,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusM,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                file.title,
                                style: AppTextStyles.labelMedium,
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _iconForType(file.type),
                                size: 16,
                                color: _colorForType(file.type),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _iconForType(ContentFileType t) => switch (t) {
    ContentFileType.pdf => Icons.picture_as_pdf_rounded,
    ContentFileType.audio => Icons.audiotrack_rounded,
    ContentFileType.video => Icons.play_circle_rounded,
    ContentFileType.image => Icons.image_rounded,
    ContentFileType.document => Icons.description_rounded,
  };

  Color _colorForType(ContentFileType t) => switch (t) {
    ContentFileType.pdf => AppColors.error,
    ContentFileType.audio => AppColors.primary,
    ContentFileType.video => AppColors.secondary,
    ContentFileType.image => AppColors.success,
    ContentFileType.document => const Color(0xFF9C27B0),
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// _FileCard
// ══════════════════════════════════════════════════════════════════════════════

class _FileCard extends StatelessWidget {
  final ContentFileEntity file;
  final VoidCallback onTap;

  const _FileCard({required this.file, required this.onTap});

  Color get _color => switch (file.type) {
    ContentFileType.pdf => AppColors.error,
    ContentFileType.audio => AppColors.primary,
    ContentFileType.video => AppColors.secondary,
    ContentFileType.image => AppColors.success,
    ContentFileType.document => const Color(0xFF9C27B0),
  };

  IconData get _icon => switch (file.type) {
    ContentFileType.pdf => Icons.picture_as_pdf_rounded,
    ContentFileType.audio => Icons.audiotrack_rounded,
    ContentFileType.video => Icons.play_circle_rounded,
    ContentFileType.image => Icons.image_rounded,
    ContentFileType.document => Icons.description_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // أيقونة النوع
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: Icon(_icon, color: _color, size: 28),
          ),

          const Spacer(),

          // العنوان
          Text(
            file.title,
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // المعلومات
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(file.sizeLabel, style: AppTextStyles.labelSmall),
              const SizedBox(width: 4),
              Text('${file.type.label} ·', style: AppTextStyles.labelSmall),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            _timeAgo(file.uploadedAt),
            style: AppTextStyles.labelSmall,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    if (diff.inDays < 30) return 'منذ ${(diff.inDays / 7).floor()} أسابيع';
    return 'منذ ${(diff.inDays / 30).floor()} شهر';
  }
}
