import 'package:equatable/equatable.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/domain/payment_status_label.dart';

/// Roles shown in the Admin academy directory, in display order.
enum DirectoryRole {
  student(AppRoles.student, 'طالب', 'الطلاب'),
  parent(AppRoles.parent, 'ولي أمر', 'أولياء الأمور'),
  teacher(AppRoles.teacher, 'معلم', 'المعلمون'),
  assistant(AppRoles.assistantTeacher, 'مساعد مدرس', 'المساعدون'),
  supervisor(AppRoles.supervisor, 'مشرف', 'المشرفون'),
  admin(AppRoles.admin, 'مسؤول', 'المسؤولون');

  const DirectoryRole(this.wire, this.label, this.plural);
  final String wire;
  final String label;
  final String plural;

  static DirectoryRole? fromWire(String? raw) {
    for (final r in values) {
      if (r.wire == raw) return r;
    }
    return null;
  }

  static String labelOf(String? wire) => fromWire(wire)?.label ?? 'حساب';
}

enum DirectoryStatusFilter {
  all('الكل'),
  active('نشط'),
  inactive('غير نشط');

  const DirectoryStatusFilter(this.label);
  final String label;
}

/// Relationship filters that map to one bounded query each.
enum DirectoryRelationFilter {
  none('بدون تصفية'),
  studentsWithoutHalaqa('طلاب بلا حلقة'),
  parentsWithoutChildren('أولياء أمور بلا أبناء مرتبطين');

  const DirectoryRelationFilter(this.label);
  final String label;
}

enum HalaqaListFilter {
  all('كل الحلقات'),
  active('النشطة'),
  withoutSupervisor('بلا مشرف'),
  activeCover('بها تغطية مؤقتة');

  const HalaqaListFilter(this.label);
  final String label;
}

/// A person as listed in the directory. [uid] is used for navigation only and
/// is never rendered; people are identified on screen by name, role and
/// academy code.
class DirectoryPerson extends Equatable {
  final String uid;
  final String name;
  final String role;
  final String academyRef;
  final bool isActive;

  const DirectoryPerson({
    required this.uid,
    required this.name,
    required this.role,
    this.academyRef = '',
    this.isActive = true,
  });

  factory DirectoryPerson.fromUser(String uid, Map<String, dynamic> data) =>
      DirectoryPerson(
        uid: uid,
        name: '${data['name'] ?? ''}'.trim(),
        role: '${data['role'] ?? ''}',
        academyRef: '${data['academyRef'] ?? ''}'.trim(),
        isActive: data['isActive'] != false,
      );

  String get displayName => name.isEmpty ? DirectoryRole.labelOf(role) : name;
  String get roleLabel => DirectoryRole.labelOf(role);

  /// "طالب · S-003" — the readable identity shown under a name.
  String get caption =>
      academyRef.isEmpty ? roleLabel : '$roleLabel · $academyRef';

  @override
  List<Object?> get props => [uid, name, role, academyRef, isActive];
}

class DirectoryHalaqa extends Equatable {
  final String id;
  final String name;
  final String academyRef;
  final String status;
  final String teacherName;
  final String supervisorName;
  final int studentCount;
  final int assistantCount;
  final bool hasActiveCover;

  const DirectoryHalaqa({
    required this.id,
    required this.name,
    this.academyRef = '',
    this.status = 'active',
    this.teacherName = '',
    this.supervisorName = '',
    this.studentCount = 0,
    this.assistantCount = 0,
    this.hasActiveCover = false,
  });

  String get displayName => name.isEmpty ? 'حلقة بدون اسم' : name;
  bool get isOpen => status != 'archived' && status != 'closed';

  @override
  List<Object?> get props => [
    id,
    name,
    academyRef,
    status,
    teacherName,
    supervisorName,
    studentCount,
    assistantCount,
    hasActiveCover,
  ];
}

/// One page of a bounded, cursor-paginated query. [cursor] is opaque to the UI.
class DirectoryPage<T> {
  final List<T> items;
  final Object? cursor;
  final bool hasMore;

  const DirectoryPage({required this.items, this.cursor, this.hasMore = false});

  static DirectoryPage<T> empty<T>() => DirectoryPage<T>(items: const []);
}

/// What a person does in one halaqa.
enum HalaqaRole {
  primaryTeacher('المعلم الأساسي'),
  supervisor('المشرف'),
  assistant('مساعد مدرس'),
  cover('تغطية مؤقتة'),
  student('طالب');

  const HalaqaRole(this.label);
  final String label;
}

class HalaqaStaff extends Equatable {
  final DirectoryPerson? teacher;
  final DirectoryPerson? supervisor;
  final List<DirectoryPerson> assistants;
  final DirectoryPerson? cover;

  const HalaqaStaff({
    this.teacher,
    this.supervisor,
    this.assistants = const [],
    this.cover,
  });

  @override
  List<Object?> get props => [teacher, supervisor, assistants, cover];
}

/// A halaqa seen from a person's profile: the person's role in it plus the
/// halaqa's staff, so related profiles are one tap away.
class HalaqaLink extends Equatable {
  final DirectoryHalaqa halaqa;
  final HalaqaRole role;
  final HalaqaStaff staff;

  const HalaqaLink({
    required this.halaqa,
    required this.role,
    this.staff = const HalaqaStaff(),
  });

  @override
  List<Object?> get props => [halaqa, role, staff];
}

class ChildSummary extends Equatable {
  final DirectoryPerson child;
  final List<HalaqaLink> halaqat;

  const ChildSummary({required this.child, this.halaqat = const []});

  @override
  List<Object?> get props => [child, halaqat];
}

class PaymentSummary extends Equatable {
  final String studentName;
  final num amount;
  final String status;
  final DateTime? dueDate;

  const PaymentSummary({
    required this.studentName,
    required this.amount,
    required this.status,
    this.dueDate,
  });

  String get statusLabel => paymentStatusLabel(status);

  @override
  List<Object?> get props => [studentName, amount, status, dueDate];
}

/// One append-only relationship change, already rendered with names.
class RelationshipEvent extends Equatable {
  final String kind;
  final String operation;
  final DateTime? at;
  final String actorName;
  final String description;

  const RelationshipEvent({
    required this.kind,
    required this.operation,
    required this.at,
    required this.actorName,
    required this.description,
  });

  @override
  List<Object?> get props => [kind, operation, at, actorName, description];
}

class PersonProfile extends Equatable {
  final DirectoryPerson person;

  /// Halaqat the person belongs to, with the person's role in each.
  final List<HalaqaLink> halaqat;
  final List<DirectoryPerson> parents;
  final List<DirectoryPerson> siblings;
  final List<ChildSummary> children;

  /// Students reached through the person's staff halaqat (deduplicated).
  final List<DirectoryPerson> students;
  final bool studentsTruncated;

  /// Teachers and assistants of a supervisor's halaqat.
  final List<DirectoryPerson> staff;
  final List<PaymentSummary> payments;
  final List<RelationshipEvent> history;

  const PersonProfile({
    required this.person,
    this.halaqat = const [],
    this.parents = const [],
    this.siblings = const [],
    this.children = const [],
    this.students = const [],
    this.studentsTruncated = false,
    this.staff = const [],
    this.payments = const [],
    this.history = const [],
  });

  @override
  List<Object?> get props => [
    person,
    halaqat,
    parents,
    siblings,
    children,
    students,
    studentsTruncated,
    staff,
    payments,
    history,
  ];
}

class StudentWithParents extends Equatable {
  final DirectoryPerson student;
  final List<DirectoryPerson> parents;

  const StudentWithParents({required this.student, this.parents = const []});

  @override
  List<Object?> get props => [student, parents];
}

class CoverPeriod extends Equatable {
  final DirectoryPerson cover;
  final String coverRole;
  final String status;
  final String reason;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const CoverPeriod({
    required this.cover,
    required this.coverRole,
    required this.status,
    this.reason = '',
    this.startedAt,
    this.endedAt,
  });

  bool get isActive => status == 'active';

  @override
  List<Object?> get props => [cover, coverRole, status, reason, startedAt, endedAt];
}

class HalaqaProfile extends Equatable {
  final DirectoryHalaqa halaqa;
  final HalaqaStaff staff;
  final List<String> schedule;
  final List<StudentWithParents> students;
  final List<CoverPeriod> coverPeriods;
  final List<RelationshipEvent> history;

  const HalaqaProfile({
    required this.halaqa,
    this.staff = const HalaqaStaff(),
    this.schedule = const [],
    this.students = const [],
    this.coverPeriods = const [],
    this.history = const [],
  });

  @override
  List<Object?> get props => [halaqa, staff, schedule, students, coverPeriods, history];
}

/// Account status from `adminGetMemberAccount`. Never carries a password.
class MemberAccount extends Equatable {
  final String loginKind;
  final String username;
  final bool isActive;
  final String staffStatus;
  final bool mustChangePassword;
  final bool? authDisabled;
  final DateTime? lastSignInAt;
  final DateTime? createdAt;
  final DateTime? credentialsIssuedAt;
  final DateTime? passwordChangedAt;
  final bool canResetPassword;
  final List<({DateTime? at, String actorName})> recoveries;

  const MemberAccount({
    required this.loginKind,
    required this.username,
    required this.isActive,
    this.staffStatus = '',
    required this.mustChangePassword,
    this.authDisabled,
    this.lastSignInAt,
    this.createdAt,
    this.credentialsIssuedAt,
    this.passwordChangedAt,
    required this.canResetPassword,
    this.recoveries = const [],
  });

  static DateTime? _ms(Object? raw) =>
      raw is num ? DateTime.fromMillisecondsSinceEpoch(raw.toInt()) : null;

  factory MemberAccount.fromMap(Map<String, dynamic> m) => MemberAccount(
    loginKind: '${m['loginKind'] ?? 'none'}',
    username: '${m['username'] ?? ''}',
    isActive: m['isActive'] != false,
    staffStatus: '${m['staffStatus'] ?? ''}',
    mustChangePassword: m['mustChangePassword'] == true,
    authDisabled: m['authDisabled'] is bool ? m['authDisabled'] as bool : null,
    lastSignInAt: _ms(m['lastSignInAtMs']),
    createdAt: _ms(m['createdAtMs']),
    credentialsIssuedAt: _ms(m['credentialsIssuedAtMs']),
    passwordChangedAt: _ms(m['passwordChangedAtMs']),
    canResetPassword: m['canResetPassword'] == true,
    recoveries: [
      for (final r in (m['recoveries'] as List? ?? const []))
        if (r is Map) (at: _ms(r['atMs']), actorName: '${r['actorName'] ?? ''}'),
    ],
  );

  String get loginLabel => switch (loginKind) {
    'username' => 'اسم مستخدم الأكاديمية',
    'email' => 'البريد الإلكتروني',
    _ => 'لا توجد بيانات دخول',
  };

  @override
  List<Object?> get props => [
    loginKind,
    username,
    isActive,
    staffStatus,
    mustChangePassword,
    authDisabled,
    lastSignInAt,
    createdAt,
    credentialsIssuedAt,
    passwordChangedAt,
    canResetPassword,
    recoveries,
  ];
}

/// One real count from the server, with where it leads in the directory.
class StructureCount extends Equatable {
  final String label;
  final int count;
  final DirectoryRole? role;
  final DirectoryStatusFilter status;
  final DirectoryRelationFilter relation;
  final HalaqaListFilter? halaqaFilter;

  const StructureCount({
    required this.label,
    required this.count,
    this.role,
    this.status = DirectoryStatusFilter.all,
    this.relation = DirectoryRelationFilter.none,
    this.halaqaFilter,
  });

  @override
  List<Object?> get props => [label, count, role, status, relation, halaqaFilter];
}

/// Normalizes a typed academy code ("s3", "S-003", "s 003") to "S-003";
/// returns null when the text is not a code.
String? normalizeAcademyRef(String raw) {
  final m = RegExp(r'^\s*([A-Za-z])\s*-?\s*(\d{1,6})\s*$').firstMatch(raw);
  if (m == null) return null;
  final n = int.parse(m.group(2)!);
  return '${m.group(1)!.toUpperCase()}-${n.toString().padLeft(3, '0')}';
}
