import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/usecases/usecases.dart';

/// Test helper that returns success without invoking real logic.
class DummyUseCase implements UseCase<Unit, NoParams> {
  const DummyUseCase();

  @override
  Future<Either<Failure, Unit>> call(NoParams params) async =>
      const Right(unit);
}
