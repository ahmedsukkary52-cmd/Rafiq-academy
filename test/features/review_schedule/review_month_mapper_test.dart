import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:rafiq_academy/features/review_schedule/data/mappers/review_month_mapper.dart';
import 'package:rafiq_academy/features/review_schedule/data/models/review_schedule_doc_model.dart';
import 'package:rafiq_academy/features/review_schedule/domain/entities/review_item_entity.dart';

void main() {
  const mapper = ReviewMonthMapper();

  ReviewScheduleDocModel doc({
    required DateTime date,
    String id = 'r1',
    String surahFrom = 'البقرة',
    String surahTo = 'البقرة',
    int ayahFrom = 1,
    int ayahTo = 5,
    bool isDone = false,
  }) {
    return ReviewScheduleDocModel(
      id: id,
      studentId: 's1',
      date: date,
      surahFrom: surahFrom,
      surahTo: surahTo,
      ayahFrom: ayahFrom,
      ayahTo: ayahTo,
      isDone: isDone,
    );
  }

  test('gregorianRangeForHijriMonth is half-open and spans ~29–30 days', () {
    final range = mapper.gregorianRangeForHijriMonth(
      hijriYear: 1446,
      hijriMonth: 1,
    );
    expect(range.end.isAfter(range.start), isTrue);
    final days = range.end.difference(range.start).inDays;
    expect(days, greaterThanOrEqualTo(28));
    expect(days, lessThanOrEqualTo(31));
  });

  test('map statuses completed / today / upcoming for current Hijri month', () {
    final today = DateTime(2024, 7, 17);
    final yesterday = DateTime(2024, 7, 16);
    final tomorrow = DateTime(2024, 7, 18);
    final h = HijriCalendar.fromDate(today);

    final month = mapper.map(
      hijriYear: h.hYear,
      hijriMonth: h.hMonth,
      now: today,
      docs: [
        doc(date: yesterday, id: 'past'),
        doc(date: today, id: 'today'),
        doc(date: tomorrow, id: 'future'),
        doc(date: yesterday, id: 'done', isDone: true, ayahFrom: 1, ayahTo: 1),
        // Outside month — should be dropped.
        doc(date: DateTime(2020, 1, 1), id: 'old'),
      ],
    );

    expect(month.hijriYear, h.hYear);
    expect(month.hijriMonth, h.hMonth);
    expect(month.monthTitle, contains(ReviewMonthMapper.monthNames[h.hMonth]));
    expect(month.daysWithReview, isNotEmpty);

    ReviewItemEntity byId(String id) =>
        month.weekItems.singleWhere((e) => e.id == id);

    expect(month.weekItems.any((e) => e.id == 'old'), isFalse);
    expect(byId('today').status, ReviewItemStatus.today);
    expect(byId('done').status, ReviewItemStatus.completed);
    expect(byId('future').status, ReviewItemStatus.upcoming);
    expect(byId('past').status, ReviewItemStatus.upcoming);
    expect(byId('today').versesCount, 5);
    expect(byId('today').rangeLabel, contains('البقرة'));
  });

  test('ayah-only docs get آيات label and verse count', () {
    final today = DateTime(2024, 7, 17);
    final h = HijriCalendar.fromDate(today);
    final month = mapper.map(
      hijriYear: h.hYear,
      hijriMonth: h.hMonth,
      now: today,
      docs: [
        doc(
          date: today,
          id: 'ayah-only',
          surahFrom: '',
          surahTo: '',
          ayahFrom: 2,
          ayahTo: 4,
        ),
      ],
    );
    final item = month.weekItems.singleWhere((e) => e.id == 'ayah-only');
    expect(item.versesCount, 3);
    expect(item.rangeLabel, 'آيات 2-4');
  });
}
