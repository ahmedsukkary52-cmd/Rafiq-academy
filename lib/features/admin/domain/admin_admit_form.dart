/// Client-side checks for the W8 staff admit form (no Firestore, no new fields).
///
/// Account create is out of scope (Rule 1). Membership writes stay in
/// [ApproveNewStudentUseCase] → Academy Admission.
class AdminAdmitFormValidation {
  const AdminAdmitFormValidation._();

  static String? error({required String studentId, required String halaqaId}) {
    if (studentId.trim().isEmpty) return 'أدخل معرّف الطالب';
    if (halaqaId.trim().isEmpty) return 'أدخل معرّف الحلقة';
    return null;
  }
}
