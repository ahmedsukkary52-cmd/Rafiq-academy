import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';

/// Reads a halaqa's display name from its `halaqat` document. Firestore Rules
/// decide which caller may read which halaqa.
abstract interface class HalaqaNameReader {
  Future<Either<Failure, String>> getHalaqaName(String halaqaId);
}
