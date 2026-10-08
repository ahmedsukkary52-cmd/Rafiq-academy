import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/quran_text_bundle.dart';

abstract class QuranTextRepository {
  /// Loads full Uthmani mushaf text (cache-first).
  Future<Either<Failure, QuranTextBundle>> loadQuranText();
}
