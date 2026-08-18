import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/parent/presentation/parent_home_nav.dart';

void main() {
  group('ParentHomeNav', () {
    test('bottom nav has five locked destinations', () {
      expect(ParentHomeNav.labels, [
        'الرئيسية',
        'أبنائي',
        'الرسائل',
        'المتجر',
        'الحساب',
      ]);
      expect(ParentHomeNav.labels[ParentHomeNav.storeIndex], 'المتجر');
      expect(ParentHomeNav.labels[ParentHomeNav.accountIndex], 'الحساب');
      expect(ParentHomeNav.labels, isNot(contains('الدعم')));
    });
  });
}
