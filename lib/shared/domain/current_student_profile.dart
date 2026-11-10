/// The signed-in student's loaded profile, read on demand so every read sees
/// the latest value. Fields are null until the profile has loaded.
abstract interface class CurrentStudentProfile {
  String? get name;
  String? get halaqaId;
}
