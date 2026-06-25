import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/content_file_entity.dart';
import '../repositories/content_library_repository.dart';

@lazySingleton
class GetFilesUseCase extends UseCase<List<ContentFileEntity>, GetFilesParams> {
  final ContentLibraryRepository repository;

  GetFilesUseCase(this.repository);

  @override
  Future<Either<Failure, List<ContentFileEntity>>> call(
    GetFilesParams params,
  ) => repository.getFiles(
    halaqaId: params.halaqaId,
    filterType: params.filterType,
  );
}

@lazySingleton
class UploadFileUseCase {
  final ContentLibraryRepository repository;

  UploadFileUseCase(this.repository);

  /// بنرجع Stream لمتابعة نسبة الرفع في الـ UI
  Stream<Either<Failure, double>> call(UploadFileParams params) =>
      repository.uploadFile(
        file: params.file,
        title: params.title,
        type: params.type,
        uploadedBy: params.uploadedBy,
        uploaderName: params.uploaderName,
        halaqaId: params.halaqaId,
      );
}

@lazySingleton
class DeleteFileUseCase extends UseCase<Unit, ContentFileEntity> {
  final ContentLibraryRepository repository;

  DeleteFileUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ContentFileEntity params) =>
      repository.deleteFile(params);
}

// ── Params ────────────────────────────────────────────────────────────────────

class GetFilesParams extends Equatable {
  final String? halaqaId;
  final ContentFileType? filterType;

  const GetFilesParams({this.halaqaId, this.filterType});

  @override
  List<Object?> get props => [halaqaId, filterType];
}

class UploadFileParams extends Equatable {
  final File file;
  final String title;
  final ContentFileType type;
  final String uploadedBy;
  final String uploaderName;
  final String? halaqaId;

  const UploadFileParams({
    required this.file,
    required this.title,
    required this.type,
    required this.uploadedBy,
    required this.uploaderName,
    this.halaqaId,
  });

  @override
  List<Object?> get props => [title, type, uploadedBy, halaqaId];
}
