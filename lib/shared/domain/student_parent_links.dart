import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';

/// Student UIDs → linked parent profile IDs (`parentProfiles.childrenIds`),
/// used to start a staff → parent conversation. IDs only: the parent's
/// display data comes from the chat participant read.
abstract interface class StudentParentLinkReader {
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  );
}
