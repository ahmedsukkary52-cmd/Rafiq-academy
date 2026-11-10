import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';

/// User UIDs → display names, for labelling staff and students in lists.
abstract interface class UserDisplayNameReader {
  Future<Either<Failure, Map<String, String>>> getUserDisplayNames(
    List<String> userIds,
  );
}
