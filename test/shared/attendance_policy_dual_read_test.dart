import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  const halaqaId = 'halaqa1';
  final day = DateTime(2026, 9, 28);
  final legacyKey = AttendancePolicy.sessionIdForDay(
    halaqaId: halaqaId,
    day: day,
  );

  test('stored real session belongs to its own id', () {
    expect(
      AttendancePolicy.belongsToSession(
        recordSessionId: 'sessRealA',
        recordHalaqaId: halaqaId,
        recordDate: day,
        sessionId: 'sessRealA',
        halaqaId: halaqaId,
      ),
      isTrue,
    );
  });

  test('stored real session belongs to the legacy key of the same day', () {
    expect(
      AttendancePolicy.belongsToSession(
        recordSessionId: 'sessRealA',
        recordHalaqaId: halaqaId,
        recordDate: day,
        sessionId: legacyKey,
        halaqaId: halaqaId,
      ),
      isTrue,
    );
  });

  test('stored real session does not belong to another day key', () {
    expect(
      AttendancePolicy.belongsToSession(
        recordSessionId: 'sessRealA',
        recordHalaqaId: halaqaId,
        recordDate: day,
        sessionId: AttendancePolicy.sessionIdForDay(
          halaqaId: halaqaId,
          day: DateTime(2026, 9, 29),
        ),
        halaqaId: halaqaId,
      ),
      isFalse,
    );
  });

  test('stored real session does not belong to another real session', () {
    expect(
      AttendancePolicy.belongsToSession(
        recordSessionId: 'sessRealA',
        recordHalaqaId: halaqaId,
        recordDate: day,
        sessionId: 'sessRealB',
        halaqaId: halaqaId,
      ),
      isFalse,
    );
  });

  test('another halaqa never matches', () {
    expect(
      AttendancePolicy.belongsToSession(
        recordSessionId: 'sessRealA',
        recordHalaqaId: 'halaqa2',
        recordDate: day,
        sessionId: legacyKey,
        halaqaId: halaqaId,
      ),
      isFalse,
    );
  });

  test('legacy row without sessionId falls back to its day key', () {
    expect(
      AttendancePolicy.belongsToSession(
        recordSessionId: null,
        recordHalaqaId: halaqaId,
        recordDate: day,
        sessionId: legacyKey,
        halaqaId: halaqaId,
      ),
      isTrue,
    );
  });
}
