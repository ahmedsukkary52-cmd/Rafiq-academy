import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/quran_text_bundle.dart';
import '../../domain/repositories/quran_text_repository.dart';
import '../datasources/quran_text_remote_datasource.dart';

@LazySingleton(as: QuranTextRepository)
class QuranTextRepositoryImpl implements QuranTextRepository {
  final QuranTextRemoteDatasource remote;

  QuranTextRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, QuranTextBundle>> loadQuranText() async {
    try {
      final bundle = await remote.fetchQuranText();
      return Right(bundle);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
