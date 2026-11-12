import 'package:flutter/foundation.dart';

/// App-wide counter bumped after a successful write that changes academy
/// structure (halaqat, rosters, accounts). Long-lived blocs keep cached
/// directories; screens compare the revision they last loaded against this
/// value and reload instead of showing stale data until the next sign-in.
class AcademyDataRevision {
  AcademyDataRevision._();

  static final ValueNotifier<int> structure = ValueNotifier<int>(0);

  static void bumpStructure() => structure.value++;
}
