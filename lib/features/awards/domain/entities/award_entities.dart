import 'package:equatable/equatable.dart';

enum AwardType {
  completionBadge,
  performanceStars,
  perfectAttendance,
  studentOfWeek,
  attendance,
  completion,
  performance,
  achievement,
  custom,
}

extension AwardTypeInfo on AwardType {
  String get title => switch (this) {
    AwardType.completionBadge => 'شارة الإتمام',
    AwardType.performanceStars => 'نجوم الأداء',
    AwardType.perfectAttendance => 'حضور مثالي',
    AwardType.studentOfWeek => 'طالب الأسبوع',
    AwardType.attendance => 'حضور',
    AwardType.completion => 'إتمام',
    AwardType.performance => 'أداء',
    AwardType.achievement => 'إنجاز',
    AwardType.custom => 'مخصص',
  };

  String get description => switch (this) {
    AwardType.completionBadge => 'ختم سورة أو جزء',
    AwardType.performanceStars => 'منح نجوم للتحفيظ',
    AwardType.perfectAttendance => 'شهر بدون غياب',
    AwardType.studentOfWeek => 'تميز أسبوعي',
    AwardType.attendance => 'جائزة مرتبطة بالحضور',
    AwardType.completion => 'جائزة إتمام حفظ أو جزء',
    AwardType.performance => 'جائزة تميز في الأداء',
    AwardType.achievement => 'جائزة إنجاز عام',
    AwardType.custom => 'جائزة بعنوان ووصف حر',
  };

  String get firestoreKey => switch (this) {
    AwardType.completionBadge => 'completion_badge',
    AwardType.performanceStars => 'performance_stars',
    AwardType.perfectAttendance => 'perfect_attendance',
    AwardType.studentOfWeek => 'student_of_week',
    AwardType.attendance => 'attendance',
    AwardType.completion => 'completion',
    AwardType.performance => 'performance',
    AwardType.achievement => 'achievement',
    AwardType.custom => 'custom',
  };

  /// Maps legacy keys onto the 5 form categories used in create/receive UI.
  AwardType get formCategory => switch (this) {
    AwardType.perfectAttendance || AwardType.attendance => AwardType.attendance,
    AwardType.completionBadge || AwardType.completion => AwardType.completion,
    AwardType.performanceStars || AwardType.performance => AwardType.performance,
    AwardType.studentOfWeek || AwardType.achievement => AwardType.achievement,
    AwardType.custom => AwardType.custom,
  };

  static const catalogPresets = <AwardType>[
    AwardType.completionBadge,
    AwardType.performanceStars,
    AwardType.perfectAttendance,
    AwardType.studentOfWeek,
  ];

  static const formTypes = <AwardType>[
    AwardType.attendance,
    AwardType.completion,
    AwardType.performance,
    AwardType.achievement,
    AwardType.custom,
  ];

  static AwardType fromKey(String key) => switch (key) {
    'completion_badge' => AwardType.completionBadge,
    'performance_stars' => AwardType.performanceStars,
    'perfect_attendance' => AwardType.perfectAttendance,
    'student_of_week' => AwardType.studentOfWeek,
    'attendance' => AwardType.attendance,
    'completion' => AwardType.completion,
    'performance' => AwardType.performance,
    'achievement' => AwardType.achievement,
    'custom' => AwardType.custom,
    _ => AwardType.custom,
  };
}

class GrantedAwardEntity extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String? studentImageUrl;
  final AwardType type;
  final String? note;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? imageStoragePath;

  /// Local file path used only as grant input; never persisted.
  final String? localImagePath;
  final String grantedBy;
  final String halaqaId;
  final String? halaqaName;
  final List<String> halaqaIds;
  final List<String> halaqaNames;
  final DateTime grantedAt;
  final List<String> recipientStudentIds;
  final int recipientCount;

  const GrantedAwardEntity({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentImageUrl,
    required this.type,
    this.note,
    this.title = '',
    this.description,
    this.imageUrl,
    this.imageStoragePath,
    this.localImagePath,
    required this.grantedBy,
    required this.halaqaId,
    this.halaqaName,
    this.halaqaIds = const [],
    this.halaqaNames = const [],
    required this.grantedAt,
    this.recipientStudentIds = const [],
    this.recipientCount = 0,
  });

  String get displayTitle {
    final named = title.trim();
    if (named.isNotEmpty) return named;
    final legacy = note?.trim() ?? '';
    if (legacy.isNotEmpty) return legacy;
    return type.title;
  }

  Set<String> get honoredStudentIds {
    final ids = recipientStudentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isNotEmpty) return ids;
    final legacy = studentId.trim();
    if (legacy.isNotEmpty) return {legacy};
    return {};
  }

  List<String> get resolvedHalaqaIds {
    final ids = <String>[];
    final seen = <String>{};
    for (final id in halaqaIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      ids.add(trimmed);
    }
    if (ids.isNotEmpty) return ids;
    final legacy = halaqaId.trim();
    return legacy.isEmpty ? const [] : [legacy];
  }

  List<String> get resolvedHalaqaNames {
    final names = halaqaNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isNotEmpty) return names;
    final legacy = halaqaName?.trim() ?? '';
    return legacy.isEmpty ? const [] : [legacy];
  }

  bool belongsToHalaqa(String id) {
    final target = id.trim();
    if (target.isEmpty) return false;
    return resolvedHalaqaIds.contains(target);
  }

  String get halaqaScopeLabel {
    final names = resolvedHalaqaNames;
    if (names.length == 1) return names.first;
    if (names.length > 1) return names.join(' + ');
    final count = resolvedHalaqaIds.length;
    if (count == 2) return 'حلقتان';
    if (count > 2) return '$count حلقات';
    return '';
  }

  @override
  List<Object?> get props => [
    id,
    studentId,
    studentName,
    type,
    note,
    title,
    description,
    imageUrl,
    grantedBy,
    halaqaId,
    halaqaName,
    halaqaIds,
    halaqaNames,
    grantedAt,
    recipientStudentIds,
    recipientCount,
  ];
}

class CertificateDataEntity extends Equatable {
  final String studentName;
  final String halaqaName;
  final String academyName;
  final String achievement;
  final DateTime date;
  final String teacherName;

  const CertificateDataEntity({
    required this.studentName,
    required this.halaqaName,
    required this.academyName,
    required this.achievement,
    required this.date,
    required this.teacherName,
  });

  @override
  List<Object?> get props => [
    studentName,
    halaqaName,
    academyName,
    achievement,
    date,
    teacherName,
  ];
}

class AwardsStatsEntity extends Equatable {
  /// Unique honored students (الطلاب المكرمون).
  final int totalRecipients;

  /// Grant documents this month.
  final int thisMonthCount;

  /// Grant documents (إجمالي الجوائز).
  final int totalAwardsCount;

  const AwardsStatsEntity({
    required this.totalRecipients,
    required this.thisMonthCount,
    required this.totalAwardsCount,
  });

  @override
  List<Object?> get props => [
    totalRecipients,
    thisMonthCount,
    totalAwardsCount,
  ];
}

AwardsStatsEntity computeAwardsStats(
  Iterable<GrantedAwardEntity> grants, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final startOfMonth = DateTime(current.year, current.month, 1);
  final honored = <String>{};
  var thisMonthCount = 0;
  var total = 0;

  for (final grant in grants) {
    total++;
    if (!grant.grantedAt.isBefore(startOfMonth)) thisMonthCount++;
    honored.addAll(grant.honoredStudentIds);
  }

  return AwardsStatsEntity(
    totalRecipients: honored.length,
    thisMonthCount: thisMonthCount,
    totalAwardsCount: total,
  );
}

Iterable<GrantedAwardEntity> awardsForHalaqa(
  Iterable<GrantedAwardEntity> grants,
  String halaqaId,
) => grants.where((grant) => grant.belongsToHalaqa(halaqaId));

List<T> mergeHalaqaScopedAwards<T>({
  required Iterable<T> byHalaqaIdField,
  required Iterable<T> byHalaqaIdsField,
  required String Function(T item) idOf,
  required DateTime Function(T item) grantedAtOf,
  int? limit,
}) {
  final merged = <String, T>{};
  for (final item in byHalaqaIdField) {
    merged.putIfAbsent(idOf(item), () => item);
  }
  for (final item in byHalaqaIdsField) {
    merged.putIfAbsent(idOf(item), () => item);
  }
  final list = merged.values.toList()
    ..sort((a, b) => grantedAtOf(b).compareTo(grantedAtOf(a)));
  if (limit == null || list.length <= limit) return list;
  return list.take(limit).toList();
}
