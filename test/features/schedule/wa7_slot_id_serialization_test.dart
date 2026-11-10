import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/schedule/data/models/halaqa_schedule_source_model.dart';
import 'package:rafiq_academy/shared/data/models/halaqa_schedule_model.dart';

void main() {
  group('WA-7 schedule slotId serialization', () {
    test('legacy map without slotId still parses', () {
      final slot = HalaqaScheduleModel.fromMap({
        'day': 'الأحد',
        'startTime': '16:00',
        'endTime': '17:00',
      });
      expect(slot.slotId, isNull);
      expect(slot.day, 'الأحد');
      final map = slot.toMap();
      expect(map.containsKey('slotId'), isFalse);
      expect(map['day'], 'الأحد');
    });

    test('round-trip preserves slotId', () {
      final slot = HalaqaScheduleModel.fromMap({
        'day': 'الإثنين',
        'startTime': '10:00',
        'endTime': '11:00',
        'slotId': 'uuid-stable-1',
      });
      expect(slot.slotId, 'uuid-stable-1');
      final map = slot.toMap();
      expect(map['slotId'], 'uuid-stable-1');
      final again = HalaqaScheduleModel.fromMap(map);
      expect(again.slotId, 'uuid-stable-1');
      expect(again.startTime, '10:00');
    });

    test('schedule source parser reads optional slotId', () {
      final slot = halaqaScheduleSlotFromMap({
        'day': 'الثلاثاء',
        'startTime': '08:00',
        'endTime': '09:00',
        'slotId': 's-9',
      });
      expect(slot.slotId, 's-9');
      final map = halaqaScheduleSlotToMap(slot);
      expect(map['slotId'], 's-9');
    });

    test('empty slotId string treated as absent', () {
      final slot = HalaqaScheduleModel.fromMap({
        'day': 'الأحد',
        'startTime': '16:00',
        'endTime': '17:00',
        'slotId': '   ',
      });
      expect(slot.slotId, isNull);
    });
  });
}
