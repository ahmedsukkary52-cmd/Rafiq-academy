import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/content_file_entity.dart';
import '../../domain/repositories/content_library_repository.dart';
import '../datasources/content_library_remote_datasource.dart';

@LazySingleton(as: ContentLibraryRepository)
class ContentLibraryRepositoryImpl implements ContentLibraryRepository {
  final ContentLibraryRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const ContentLibraryRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<ContentFileEntity>>> getFiles({
    String? halaqaId,
    ContentFileType? filterType,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getFiles(
          halaqaId: halaqaId,
          filterType: filterType,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, double>> uploadFile({
    required File file,
    required String title,
    required ContentFileType type,
    required String uploadedBy,
    required String uploaderName,
    String? halaqaId,
  }) async* {
    if (!await networkInfo.isConnected) {
      yield const Left(NetworkFailure());
      return;
    }

    yield* remoteDatasource
        .uploadFile(
          file: file,
          title: title,
          type: type,
          uploadedBy: uploadedBy,
          uploaderName: uploaderName,
          halaqaId: halaqaId,
        )
        .map<Either<Failure, double>>(Right.new)
        .handleError((e) => Left(ServerFailure(e.toString())));
  }

  @override
  Future<Either<Failure, Unit>> deleteFile(ContentFileEntity file) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.deleteFile(file);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
