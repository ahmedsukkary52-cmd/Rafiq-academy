/// Client-side validation for admin complaint response compose.
class AdminComplaintResponseFormValidation {
  const AdminComplaintResponseFormValidation._();

  static String? error({required String response}) {
    if (response.trim().isEmpty) return 'اكتب ردك قبل الإرسال';
    return null;
  }
}
