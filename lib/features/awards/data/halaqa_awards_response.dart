import '../../../shared/data/achievements_firestore_contract.dart';
import 'models/granted_award_model.dart';

/// `getHalaqaAwards` → `{awards: [{id, dateMillis, ...award fields}]}`.
/// A response without that list is a contract break, not an empty result,
/// so it throws [FormatException]. Entries that are not maps or lack an id
/// are skipped.
List<GrantedAwardModel> parseHalaqaAwardsResponse(Object? data) {
  final raw = data is Map ? data['awards'] : null;
  if (raw is! List) {
    throw const FormatException('getHalaqaAwards: missing list');
  }
  return [
    for (final item in raw)
      if (item is Map && item['id'] is String && (item['id'] as String).isNotEmpty)
        _award(Map<String, dynamic>.from(item)),
  ];
}

GrantedAwardModel _award(Map<String, dynamic> item) {
  final millis = item['dateMillis'];
  final data = <String, dynamic>{
    for (final e in item.entries)
      e.key: e.value is List ? List<String>.from((e.value as List).map((v) => '$v')) : e.value,
  }..remove('dateMillis');
  if (millis is num && millis > 0) {
    data[AchievementsFirestoreContract.dateField] =
        DateTime.fromMillisecondsSinceEpoch(millis.toInt());
  }
  return GrantedAwardModel.fromMap(item['id'] as String, data);
}
