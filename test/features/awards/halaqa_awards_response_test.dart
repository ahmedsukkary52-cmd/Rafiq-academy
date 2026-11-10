import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/awards/data/halaqa_awards_response.dart';

void main() {
  test('getHalaqaAwards rows map to granted awards with their date', () {
    final awards = parseHalaqaAwardsResponse({
      'awards': [
        {
          'id': 'g2',
          'dateMillis': 1790000100000,
          'studentId': 's3',
          'studentName': 'عمر',
          'type': 'star',
          'title': 'مشتركة',
          'grantedBy': 'admin1',
          'halaqaId': 'h2',
          'halaqaIds': ['h2', 'h1'],
          'recipientStudentIds': ['s3'],
          'recipientCount': 1,
        },
        {'id': ''},
        'not a map',
      ],
    });
    expect(awards, hasLength(1));
    final a = awards.single;
    expect(a.id, 'g2');
    expect(a.grantedAt, DateTime.fromMillisecondsSinceEpoch(1790000100000));
    expect(a.title, 'مشتركة');
    expect(a.halaqaIds, ['h2', 'h1']);
    expect(a.recipientStudentIds, ['s3']);
    expect(a.grantedBy, 'admin1');
  });

  test('a reply without the awards list is a contract break, not an empty list', () {
    expect(() => parseHalaqaAwardsResponse({'ok': true}), throwsFormatException);
    expect(() => parseHalaqaAwardsResponse(null), throwsFormatException);
    expect(parseHalaqaAwardsResponse({'awards': []}), isEmpty);
  });
}
