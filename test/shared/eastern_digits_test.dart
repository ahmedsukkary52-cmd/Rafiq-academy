import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/teacher/presentation/widgets/teacher_home_figma_cards.dart'
    as teacher_cards;
import 'package:rafiq_academy/shared/utils/eastern_digits.dart';

void main() {
  group('teacherHomeEasternDigits', () {
    test('maps every ASCII digit to its Arabic-Indic digit', () {
      expect(teacherHomeEasternDigits('0123456789'), '٠١٢٣٤٥٦٧٨٩');
    });

    test('keeps Arabic-Indic digits unchanged', () {
      expect(teacherHomeEasternDigits('٠١٢٣٤٥٦٧٨٩'), '٠١٢٣٤٥٦٧٨٩');
    });

    test('converts only the ASCII digits in mixed input', () {
      expect(
        teacherHomeEasternDigits('الحلقة 12 - ٣ طلاب'),
        'الحلقة ١٢ - ٣ طلاب',
      );
      expect(teacherHomeEasternDigits('3:05 مساءً'), '٣:٠٥ مساءً');
      expect(teacherHomeEasternDigits('85%'), '٨٥%');
    });

    test('returns an empty string for empty input', () {
      expect(teacherHomeEasternDigits(''), '');
    });

    test('keeps other characters, including Persian digits and emoji', () {
      expect(teacherHomeEasternDigits('abc ۱۲۳'), 'abc ۱۲۳');
      expect(teacherHomeEasternDigits('⭐1'), '⭐١');
    });

    test('teacher cards re-export the same shared function', () {
      expect(
        identical(
          teacher_cards.teacherHomeEasternDigits,
          teacherHomeEasternDigits,
        ),
        isTrue,
      );
    });
  });

  group('eastern digits ownership', () {
    test('declared once, in lib/shared/utils', () {
      final declaring = <String>[];
      final pattern = RegExp(
        r'^String teacherHomeEasternDigits\(',
        multiLine: true,
      );
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        if (pattern.hasMatch(file.readAsStringSync())) {
          declaring.add(file.path.replaceAll(r'\', '/'));
        }
      }
      expect(declaring, ['lib/shared/utils/eastern_digits.dart']);
    });

    test('student profile page no longer imports the teacher cards file', () {
      final source = File(
        'lib/features/staff/student_profile/presentation/pages/student_profile_page.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('teacher_home_figma_cards.dart')));
      expect(source, contains("shared/utils/eastern_digits.dart'"));
    });
  });
}
