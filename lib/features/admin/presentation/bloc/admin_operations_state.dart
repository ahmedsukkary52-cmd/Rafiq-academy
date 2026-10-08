part of 'admin_operations_bloc.dart';

const Object _unset = Object();

class AdminOperationsState extends Equatable {
  final SectionStatus directoryStatus;
  final String? directoryError;
  final List<AdminDirectoryUser> students;
  final List<AdminDirectoryUser> parents;
  final List<AdminDirectoryUser> teachers;
  final List<AdminDirectoryUser> supervisors;
  final List<HalaqaEntity> halaqat;

  final String? selectedParentId;
  final List<String> selectedParentChildren;

  final SubmissionStatus actionStatus;
  final String? actionMessage;
  final String? actionError;

  const AdminOperationsState({
    this.directoryStatus = SectionStatus.initial,
    this.directoryError,
    this.students = const [],
    this.parents = const [],
    this.teachers = const [],
    this.supervisors = const [],
    this.halaqat = const [],
    this.selectedParentId,
    this.selectedParentChildren = const [],
    this.actionStatus = SubmissionStatus.idle,
    this.actionMessage,
    this.actionError,
  });

  bool get isSubmitting => actionStatus == SubmissionStatus.submitting;

  SubmissionStatus get submissionStatus => actionStatus;

  /// The outcome text for the current [actionStatus] (error or success).
  String? get message =>
      actionStatus == SubmissionStatus.error ? actionError : actionMessage;

  String nameOf(String uid) {
    for (final list in [students, parents, teachers, supervisors]) {
      for (final u in list) {
        if (u.uid == uid) return u.displayName;
      }
    }
    return uid;
  }

  String halaqaName(String halaqaId) {
    for (final h in halaqat) {
      if (h.id == halaqaId) return h.name.trim().isEmpty ? h.id : h.name;
    }
    return halaqaId;
  }

  /// Halaqat whose roster contains [studentId] (roster SSOT).
  List<HalaqaEntity> halaqatOf(String studentId) =>
      halaqat.where((h) => h.studentIds.contains(studentId)).toList();

  AdminOperationsState copyWith({
    SectionStatus? directoryStatus,
    Object? directoryError = _unset,
    List<AdminDirectoryUser>? students,
    List<AdminDirectoryUser>? parents,
    List<AdminDirectoryUser>? teachers,
    List<AdminDirectoryUser>? supervisors,
    List<HalaqaEntity>? halaqat,
    Object? selectedParentId = _unset,
    List<String>? selectedParentChildren,
    SubmissionStatus? actionStatus,
    Object? actionMessage = _unset,
    Object? actionError = _unset,
  }) {
    return AdminOperationsState(
      directoryStatus: directoryStatus ?? this.directoryStatus,
      directoryError: identical(directoryError, _unset)
          ? this.directoryError
          : directoryError as String?,
      students: students ?? this.students,
      parents: parents ?? this.parents,
      teachers: teachers ?? this.teachers,
      supervisors: supervisors ?? this.supervisors,
      halaqat: halaqat ?? this.halaqat,
      selectedParentId: identical(selectedParentId, _unset)
          ? this.selectedParentId
          : selectedParentId as String?,
      selectedParentChildren:
          selectedParentChildren ?? this.selectedParentChildren,
      actionStatus: actionStatus ?? this.actionStatus,
      actionMessage: identical(actionMessage, _unset)
          ? this.actionMessage
          : actionMessage as String?,
      actionError: identical(actionError, _unset)
          ? this.actionError
          : actionError as String?,
    );
  }

  @override
  List<Object?> get props => [
    directoryStatus,
    directoryError,
    students,
    parents,
    teachers,
    supervisors,
    halaqat,
    selectedParentId,
    selectedParentChildren,
    actionStatus,
    actionMessage,
    actionError,
  ];
}
