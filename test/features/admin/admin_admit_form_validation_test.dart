import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/domain/admin_admit_form.dart';

void main() {
  group('AdminAdmitFormValidation', () {
    test('rejects empty student id', () {
      expect(
        AdminAdmitFormValidation.error(studentId: '  ', halaqaId: 'h1'),
        'أدخل معرّف الطالب',
      );
    });

    test('rejects empty halaqa id', () {
      expect(
        AdminAdmitFormValidation.error(studentId: 's1', halaqaId: ''),
        'أدخل معرّف الحلقة',
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
