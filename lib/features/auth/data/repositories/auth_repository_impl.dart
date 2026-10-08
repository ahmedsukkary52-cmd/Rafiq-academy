import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const AuthRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserEntity>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    return _guard(
      () => remoteDatasource.loginWithEmail(email: email, password: password),
    );
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail({
    required String email,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    return _guard(() async {
      await remoteDatasource.sendPasswordResetEmail(email: email);
      return unit;
    });
  }

  @override
  Future<Either<Failure, Unit>> logout() => _guard(() async {
    await remoteDatasource.logout();
    return unit;
  });

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() =>
      _guard(remoteDatasource.getCurrentUser);

  @override
  Stream<String?> get sessionUidChanges => remoteDatasource.sessionUidChanges;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, reason: e.reason));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
