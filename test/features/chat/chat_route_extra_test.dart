import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/chat/presentation/chat_route_extra.dart';

void main() {
  group('ChatRouteExtra.parse', () {
    test('reads Map<String, String?> used by teacher inbox navigation', () {
      final extra = <String, String?>{'name': 'أحمد', 'image': 'https://img'};
      expect(ChatRouteExtra.parse(extra)['name'], 'أحمد');
      expect(ChatRouteExtra.parse(extra)['image'], 'https://img');
    });

    test('reads Map<String, String> inferred when image is non-null', () {
      final extra = <String, String>{
        'name': 'سارة',
        'image': 'https://img/s.png',
      };
      final parsed = ChatRouteExtra.parse(extra);
      expect(parsed['name'], 'سارة');
      expect(parsed['image'], 'https://img/s.png');
    });

    test('reads untyped Map<String, dynamic> without a failing cast', () {
      final extra = <String, dynamic>{
        'name': 'ولي',
        'imageUrl': 'https://parent.png',
      };
      expect(() => extra as Map<String, String?>, throwsA(isA<TypeError>()));
      final parsed = ChatRouteExtra.parse(extra);
      expect(parsed['name'], 'ولي');
      expect(parsed['image'], 'https://parent.png');
    });

    test('null extra yields empty map', () {
      expect(ChatRouteExtra.parse(null), isEmpty);
    });
  });
}
