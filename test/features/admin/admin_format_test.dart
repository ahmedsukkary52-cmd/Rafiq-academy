import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/presentation/admin_format.dart';

void main() {
  test('formatAdminCount formats thousands', () {
    expect(formatAdminCount(1842), '1,842');
    expect(formatAdminCount(null), '—');
  });
}
