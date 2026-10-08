import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/mushaf_position.dart';

/// C15 last-read persistence — not memorization progress.
abstract class MushafReadingRepository {
  Future<Either<Failure, MushafPosition?>> getLastRead(String studentId);

  Future<Either<Failure, Unit>> saveLastRead({
    required String studentId,
    required MushafPosition position,
  });
}
