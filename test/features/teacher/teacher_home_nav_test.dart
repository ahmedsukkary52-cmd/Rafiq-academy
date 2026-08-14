import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/teacher/presentation/teacher_home_nav.dart';

void main() {
  group('TeacherHomeNav', () {
    test('replaces Posts with Awards at index 2', () {
      expect(TeacherHomeNav.awardsIndex, 2);
      expect(TeacherHomeNav.labels, [
        'الرئيسية',
        'الطلاب',
        'الجوائز',
        'الرسائل',
        'حسابي',
      ]);
      expect(TeacherHomeNav.labels, isNot(contains('المنشورات')));
      expect(TeacherHomeNav.labels[TeacherHomeNav.awardsIndex], 'الجوائز');
    });
  });

  group('resolveTeacherAwardsHalaqaId', () {
    test('prefers selectedHalaqaId', () {
      expect(
        resolveTeacherAwardsHalaqaId(
          selectedHalaqaId: 'selected',
          teacherHalaqaIds: const ['first', 'second'],
        ),
        'selected',
      );
    });

    test('falls back to first teacher halaqa', () {
      expect(
        resolveTeacherAwardsHalaqaId(
          selectedHalaqaId: null,
          teacherHalaqaIds: const ['first', 'second'],
        ),
        'first',
      );
      expect(
        resolveTeacherAwardsHalaqaId(
          selectedHalaqaId: '  ',
          teacherHalaqaIds: const ['', 'second'],
        ),
        'second',
      );
    });

    test('returns null when nothing is available', () {
      expect(
        resolveTeacherAwardsHalaqaId(
          selectedHalaqaId: null,
          teacherHalaqaIds: const [],
        ),
        isNull,
      );
    });
  });
}
