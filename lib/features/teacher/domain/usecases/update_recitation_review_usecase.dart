import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/academy_event_publication.dart';
import '../repositories/teacher_repository.dart';

@lazySingleton
class UpdateRecitationReviewUseCase
    extends UseCase<AcademyEventPublication, UpdateRecitationReviewParams> {
  final TeacherRepository repository;

  UpdateRecitationReviewUseCase(this.repository);

  @override
  Future<Either<Failure, AcademyEventPublication>> call(
    UpdateRecitationReviewParams params,
  ) => repository.updateRecitationReview(params);
}
