import 'bloc/parent_state.dart';

/// Parent may only open child-scoped screens for linked childrenIds.
class ParentChildAccess {
  const ParentChildAccess._();

  static bool owns({required ParentState state, required String studentId}) {
    final id = studentId.trim();
    if (id.isEmpty) return false;
    for (final childId in state.childrenIds) {
      if (childId.trim() == id) return true;
    }
    return false;
  }

  static const String deniedMessage =
      'لا يمكن عرض بيانات طالب غير مرتبط بولي الأمر';
}
