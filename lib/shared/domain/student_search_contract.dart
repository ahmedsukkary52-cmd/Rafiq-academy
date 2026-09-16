import 'arabic_search_normalizer.dart';

/// C13 / WA-14 — frozen `studentSearch/{studentId}` projection contract.
///
/// `firestore.rules` and `functions/src/search/studentSearchContract.ts` are
/// authoritative; these constants exist so Dart never invents an alternate
/// field name or query shape.
///
/// The projection is CF-owned: clients read only, and the read scope is
/// roster-derived through [visibleToField]. Phone and any other private
/// contact data never appear here (D16).
class StudentSearchContract {
  const StudentSearchContract._();

  static const String collection = 'studentSearch';

  static const String studentIdField = 'studentId';
  static const String fullNameField = 'fullName';
  static const String fullNameNormalizedField = 'fullNameNormalized';
  static const String halaqaIdField = 'halaqaId';
  static const String halaqaNameField = 'halaqaName';
  static const String halaqaIdsField = 'halaqaIds';
  static const String visibleToField = 'visibleTo';
  static const String updatedAtField = 'updatedAt';
  static const String normalizationVersionField = 'normalizationVersion';

  /// The complete, frozen key set of a projection document.
  static const List<String> fields = [
    studentIdField,
    fullNameField,
    fullNameNormalizedField,
    halaqaIdField,
    halaqaNameField,
    halaqaIdsField,
    visibleToField,
    updatedAtField,
    normalizationVersionField,
  ];

  /// Never present on a projection document — asserted by contract tests.
  static const List<String> forbiddenFields = [
    'phone',
    'phoneNumber',
    'email',
    'address',
    'dateOfBirth',
    'dob',
    'birthYear',
    'nationalId',
    'parentId',
    'parentIds',
    'parentName',
    'parentPhone',
    'guardianName',
    'guardianPhone',
    'payment',
    'paymentStatus',
    'paymentAccess',
    'notes',
    'isActive',
    'lifecycle',
    'role',
  ];

  /// Normal product invariant (`AcademyMembershipInvariant`).
  static const int maxHalaqaMemberships = 2;

  /// Sentinel appended to a prefix to build the Firestore `<=` range bound.
  static const String prefixRangeSuffix = '\uf8ff';

  static const int defaultSearchLimit = 25;

  static String documentPath(String studentId) {
    final id = studentId.trim();
    if (id.isEmpty) {
      throw ArgumentError('studentSearch document id must be non-empty');
    }
    return '$collection/$id';
  }

  /// Inclusive lower bound of a normalized prefix range.
  static String prefixStart(String rawQuery) =>
      ArabicSearchNormalizer.normalize(rawQuery);

  /// Inclusive upper bound of a normalized prefix range.
  static String prefixEnd(String rawQuery) =>
      '${prefixStart(rawQuery)}$prefixRangeSuffix';
}
