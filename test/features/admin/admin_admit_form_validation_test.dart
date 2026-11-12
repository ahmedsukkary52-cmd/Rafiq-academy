import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/domain/admin_admit_form.dart';

void main() {
  group('AdminAdmitFormValidation', () {
    test('rejects empty student id', () {
      expect(
        AdminAdmitFormValidation.error(studentId: '  ', halaqaId: 'h1'),
        'اختر الطالب',
      );
    });

    test('rejects empty halaqa id', () {
      expect(
        AdminAdmitFormValidation.error(studentId: 's1', halaqaId: ''),
        'اختر الحلقة',
      );
    });

    test('accepts trimmed existing ids', () {
      expect(
        AdminAdmitFormValidation.error(studentId: ' s1 ', halaqaId: ' h1 '),
        isNull,
      );
    });
  });
}
