import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/domain/admin_complaint_response_form.dart';

void main() {
  group('AdminComplaintResponseFormValidation', () {
    test('returns error when response empty', () {
      expect(
        AdminComplaintResponseFormValidation.error(response: ''),
        isNotNull,
      );
    });

    test('returns null for non-empty response', () {
      expect(
        AdminComplaintResponseFormValidation.error(response: 'شكراً لتواصلكم'),
        isNull,
      );
    });
  });
}
