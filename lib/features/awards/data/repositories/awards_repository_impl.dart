import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/award_entities.dart';
import '../../domain/repositories/awards_repository.dart';
import '../datasources/award_remote_datasource.dart';
import '../models/granted_award_model.dart';
import '../services/certificate_pdf_generator.dart';

@LazySingleton(as: AwardsRepository)
class AwardsRepositoryImpl implements AwardsRepository {
  final AwardsRemoteDatasource remoteDatasource;
  final CertificatePdfGenerator pdfGenerator;
  final NetworkInfo networkInfo;

  const AwardsRepositoryImpl({
    required this.remoteDatasource,
    required this.pdfGenerator,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, AwardsStatsEntity>> getAwardsStats(
    String halaqaId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getAwardsStats(halaqaId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<GrantedAwardEntity>>> getGrantedAwards(
    String halaqaId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getGrantedAwards(halaqaId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> grantAward(GrantedAwardEntity award) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.grantAward(
        GrantedAwardModel.fromEntity(award),
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<int>>> generateCertificatePdf(
    CertificateDataEntity data,
  ) async {
    try {
      // توليد الـ PDF محلياً (مش محتاجين اتصال إنترنت)
      final bytes = await pdfGenerator.generate(data);
      return Right(bytes);
    } catch (e) {
      return Left(ServerFailure('فشل توليد الشهادة: ${e.toString()}'));
    }
  }
}
