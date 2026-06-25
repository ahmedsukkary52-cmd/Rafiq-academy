import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/content_file_entity.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class ContentLibraryState extends Equatable {
  final SectionStatus filesStatus;
  final List<ContentFileEntity> allFiles; // كل الملفات بدون فلترة
  final ContentFileType? activeFilter;
  final String? filesError;

  /// نسبة الرفع (0.0 → 1.0) - null لو مفيش رفع جاري
  final double? uploadProgress;
  final SubmissionStatus uploadStatus;
  final String? uploadError;

  const ContentLibraryState({
    this.filesStatus = SectionStatus.initial,
    this.allFiles = const [],
    this.activeFilter,
    this.filesError,
    this.uploadProgress,
    this.uploadStatus = SubmissionStatus.idle,
    this.uploadError,
  });

  factory ContentLibraryState.initial() => const ContentLibraryState();

  /// الملفات بعد تطبيق الفلتر النشط
  List<ContentFileEntity> get filteredFiles => activeFilter == null
      ? allFiles
      : allFiles.where((f) => f.type == activeFilter).toList();

  ContentLibraryState copyWith({
    SectionStatus? filesStatus,
    List<ContentFileEntity>? allFiles,
    Object? activeFilter = _unset,
    Object? filesError = _unset,
    Object? uploadProgress = _unset,
    SubmissionStatus? uploadStatus,
    Object? uploadError = _unset,
  }) {
    return ContentLibraryState(
      filesStatus: filesStatus ?? this.filesStatus,
      allFiles: allFiles ?? this.allFiles,
      activeFilter: identical(activeFilter, _unset)
          ? this.activeFilter
          : activeFilter as ContentFileType?,
      filesError: identical(filesError, _unset)
          ? this.filesError
          : filesError as String?,
      uploadProgress: identical(uploadProgress, _unset)
          ? this.uploadProgress
          : uploadProgress as double?,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadError: identical(uploadError, _unset)
          ? this.uploadError
          : uploadError as String?,
    );
  }

  @override
  List<Object?> get props => [
    filesStatus,
    allFiles,
    activeFilter,
    filesError,
    uploadProgress,
    uploadStatus,
    uploadError,
  ];
}
