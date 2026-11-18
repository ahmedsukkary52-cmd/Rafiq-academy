import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _codeUsesFirebaseInstance(String source) {
  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
    if (trimmed.contains('FirebaseFirestore.instance')) return true;
  }
  return false;
}

void main() {
  test('broadcast audience counting lives in data, not on Firebase.instance', () {
    final data = File(
      'lib/features/admin/data/admin_broadcast_audience_count.dart',
    ).readAsStringSync();
    expect(data, contains('countBroadcastAudienceForRole'));
    expect(data, contains('required FirebaseFirestore firestore'));
    expect(_codeUsesFirebaseInstance(data), isFalse);

    final page = File(
      'lib/features/admin/presentation/pages/admin_broadcast_page.dart',
    ).readAsStringSync();
    expect(page, contains('countBroadcastAudienceForRole'));
    expect(page, contains('sl<FirebaseFirestore>()'));
    expect(_codeUsesFirebaseInstance(page), isFalse);
  });

  test('admin halaqa details loads the document via data layer + DI Firestore', () {
    final data = File(
      'lib/features/admin/data/admin_halaqa_document_loader.dart',
    ).readAsStringSync();
    expect(data, contains('loadAdminHalaqaDocument'));
    expect(data, contains('required FirebaseFirestore firestore'));
    expect(_codeUsesFirebaseInstance(data), isFalse);

    final page = File(
      'lib/features/admin/presentation/pages/admin_halaqa_details_page.dart',
    ).readAsStringSync();
    expect(page, contains('loadAdminHalaqaDocument'));
    expect(page, contains('sl<FirebaseFirestore>()'));
    expect(_codeUsesFirebaseInstance(page), isFalse);
  });
}
