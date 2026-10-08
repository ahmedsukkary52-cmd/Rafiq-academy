import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/quran_text_bundle.dart';
import '../repositories/quran_text_repository.dart';

@lazySingleton
class LoadQuranTextUseCase extends UseCase<QuranTextBundle, NoParams> {
  final QuranTextRepository repository;

  LoadQuranTextUseCase(this.repository);

  @override
  Future<Either<Failure, QuranTextBundle>> call(NoParams params) =>
      repository.loadQuranText();
}
