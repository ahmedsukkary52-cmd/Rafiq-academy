import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../domain/entities/content_file_entity.dart';

abstract class ContentLibraryEvent extends Equatable {
  const ContentLibraryEvent();

  @override
  List<Object?> get props => [];
}

class LoadFilesEvent extends ContentLibraryEvent {
  final String? halaqaId;
  final ContentFileType? filterType;

  const LoadFilesEvent({this.halaqaId, this.filterType});

  @override
  List<Object?> get props => [halaqaId, filterType];
}

class FilterFilesEvent extends ContentLibraryEvent {
  final ContentFileType? type; // null = كل الأنواع
  const FilterFilesEvent(this.type);

  @override
  List<Object?> get props => [type];
}

class UploadFileEvent extends ContentLibraryEvent {
  final File file;
  final String title;
  final ContentFileType type;
  final String uploadedBy;
  final String uploaderName;
  final String? halaqaId;

  const UploadFileEvent({
    required this.file,
    required this.title,
    required this.type,
    required this.uploadedBy,
    required this.uploaderName,
    this.halaqaId,
  });

  @override
  List<Object?> get props => [title, type, uploadedBy];
}

class ResetUploadEvent extends ContentLibraryEvent {
  const ResetUploadEvent();
}

class DeleteFileEvent extends ContentLibraryEvent {
  final ContentFileEntity file;

  const DeleteFileEvent(this.file);

  @override
  List<Object?> get props => [file.id];
}
