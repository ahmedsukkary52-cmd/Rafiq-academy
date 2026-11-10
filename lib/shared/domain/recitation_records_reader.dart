import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';
import 'recitation_record_entity.dart';

/// A student's teacher-graded recitation records, newest first (pending
/// student submissions excluded). Firestore Rules decide which caller may
/// read which student's records.
abstract interface class RecitationRecordsReader {
  Future<Either<Failure, List<RecitationRecordEntity>>> getRecitationRecords(
    String studentId,
  );
}
