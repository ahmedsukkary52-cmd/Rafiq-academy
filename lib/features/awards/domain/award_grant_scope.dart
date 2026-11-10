import 'award_recipient_selection.dart';

/// Halaqat the award sheet offers, plus a roster already loaded for one of
/// them. Drives the picker only: the grantAward callable re-checks every
/// halaqa and recipient against the caller's role.
class AwardGrantScope {
  final List<AwardHalaqaOption> halaqat;
  final String? rosterHalaqaId;
  final List<AwardRecipientStudent> roster;

  const AwardGrantScope({
    this.halaqat = const [],
    this.rosterHalaqaId,
    this.roster = const [],
  });
}

/// Read-only, live view of the signed-in grantor's [AwardGrantScope].
abstract interface class AwardGrantScopeSource {
  AwardGrantScope get state;

  /// Emits whenever the underlying grantor state changes.
  Stream<AwardGrantScope> get stream;
}
