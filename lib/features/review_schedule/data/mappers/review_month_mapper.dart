import 'package:hijri/hijri_calendar.dart';

import '../../domain/entities/review_item_entity.dart';
import '../models/review_schedule_doc_model.dart';

/// Builds [ReviewMonthEntity] from Firestore docs for a Hijri month.
class ReviewMonthMapper {
  const ReviewMonthMapper();

  static const monthNames = [
    '',
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  /// Gregorian half-open range covering every day of the Hijri month.
  ({DateTime start, DateTime end}) gregorianRangeForHijriMonth({
    required int hijriYear,
    required int hijriMonth,
  }) {
    final daysInMonth = HijriCalendar().getDaysInMonth(hijriYear, hijriMonth);
    final first = HijriCalendar().hijriToGregorian(hijriYear, hijriMonth, 1);
    final last = HijriCalendar().hijriToGregorian(
      hijriYear,
      hijriMonth,
      daysInMonth,
    );
    final start = DateTime(first.year, first.month, first.day);
    final end = DateTime(
      last.year,
      last.month,
      last.day,
    ).add(const Duration(days: 1));
    return (start: start, end: end);
  }

  ReviewMonthEntity map({
    required int hijriYear,
    required int hijriMonth,
    required List<ReviewScheduleDocModel> docs,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final todayH = HijriCalendar.fromDate(today);

    final monthItems = <ReviewItemEntity>[];
    final daysWithReview = <int>{};

    for (final doc in docs) {
      final g = DateTime(doc.date.year, doc.date.month, doc.date.day);
      final h = HijriCalendar.fromDate(g);
      if (h.hYear != hijriYear || h.hMonth != hijriMonth) continue;

      daysWithReview.add(h.hDay);
      monthItems.add(
        ReviewItemEntity(
          id: doc.id,
          gregorianDate: g,
          hijriDay: h.hDay,
          hijriMonthName: monthNames[hijriMonth],
          rangeLabel: _rangeLabel(doc),
          versesCount: _versesCount(doc),
          status: _status(doc: doc, day: g, today: today),
        ),
      );
    }

    monthItems.sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));

    final viewingCurrentMonth =
        todayH.hYear == hijriYear && todayH.hMonth == hijriMonth;
    final weekItems = viewingCurrentMonth
        ? monthItems
              .where((i) => _isInCurrentWeek(i.gregorianDate, today))
              .toList()
        : monthItems;

    return ReviewMonthEntity(
      hijriYear: hijriYear,
      hijriMonth: hijriMonth,
      monthTitle: '${monthNames[hijriMonth]} $hijriYear',
      daysWithReview: daysWithReview.toList()..sort(),
      weekItems: weekItems,
    );
  }

  ReviewItemStatus _status({
    required ReviewScheduleDocModel doc,
    required DateTime day,
    required DateTime today,
  }) {
    if (doc.isDone) return ReviewItemStatus.completed;
    if (day == today) return ReviewItemStatus.today;
    return ReviewItemStatus.upcoming;
  }

  bool _isInCurrentWeek(DateTime day, DateTime today) {
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return !day.isBefore(start) && day.isBefore(end);
  }

  String _rangeLabel(ReviewScheduleDocModel doc) {
    final from = doc.surahFrom.trim();
    final to = doc.surahTo.trim();
    if (from.isEmpty && to.isEmpty) {
      if (doc.ayahFrom > 0 || doc.ayahTo > 0) {
        return 'آيات ${doc.ayahFrom}-${doc.ayahTo}';
      }
      return 'مراجعة';
    }
    if (from == to || to.isEmpty) {
      final name = from.isNotEmpty ? from : to;
      if (doc.ayahFrom > 0 && doc.ayahTo > 0) {
        return 'سورة $name — الآيات ${doc.ayahFrom}-${doc.ayahTo}';
      }
      return 'سورة $name';
    }
    return 'من $from ${doc.ayahFrom} إلى $to ${doc.ayahTo}';
  }

  int _versesCount(ReviewScheduleDocModel doc) {
    if (doc.ayahFrom > 0 && doc.ayahTo >= doc.ayahFrom) {
      return doc.ayahTo - doc.ayahFrom + 1;
    }
    if (doc.ayahTo > 0) return doc.ayahTo;
    if (doc.ayahFrom > 0) return 1;
    return 0;
  }
}
