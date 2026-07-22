import 'package:hijri/hijri_calendar.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/review_item_entity.dart';
import 'review_schedule_remote_datasource.dart';

/// TODO: ربط بـ Firestore `reviewSchedules` الموجود في StudentRepository
/// حالياً بيانات تجريبية لعرض التقويم والقائمة.
@LazySingleton(as: ReviewScheduleRemoteDatasource)
class ReviewScheduleRemoteDatasourceImpl
    implements ReviewScheduleRemoteDatasource {
  static const _monthNames = [
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

  @override
  Future<ReviewMonthEntity> getMonth({
    required int hijriYear,
    required int hijriMonth,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final todayH = HijriCalendar.now();
    final daysWithReview = <int>{20, 22, 24, 25, 26, 27, 28, 29, 30};

    final weekItems = <ReviewItemEntity>[
      _item(
        id: 'r1',
        day: 27,
        month: hijriMonth,
        year: hijriYear,
        range: 'سورة الملك — الآيات ١-٨',
        verses: 8,
        status: ReviewItemStatus.completed,
      ),
      _item(
        id: 'r2',
        day: 28,
        month: hijriMonth,
        year: hijriYear,
        range: 'سورة الملك — الآيات ٩-١٦',
        verses: 8,
        status: todayH.hMonth == hijriMonth && todayH.hYear == hijriYear
            ? ReviewItemStatus.today
            : ReviewItemStatus.upcoming,
      ),
      _item(
        id: 'r3',
        day: 29,
        month: hijriMonth,
        year: hijriYear,
        range: 'سورة الملك — الآيات ١٧-٢٤',
        verses: 8,
        status: ReviewItemStatus.upcoming,
      ),
      _item(
        id: 'r4',
        day: 30,
        month: hijriMonth,
        year: hijriYear,
        range: 'سورة الملك — الآيات ٢٥-٣٠',
        verses: 6,
        status: ReviewItemStatus.upcoming,
      ),
    ];

    return ReviewMonthEntity(
      hijriYear: hijriYear,
      hijriMonth: hijriMonth,
      monthTitle: '${_monthNames[hijriMonth]} $hijriYear',
      daysWithReview: daysWithReview.toList()..sort(),
      weekItems: weekItems,
    );
  }

  ReviewItemEntity _item({
    required String id,
    required int day,
    required int month,
    required int year,
    required String range,
    required int verses,
    required ReviewItemStatus status,
  }) {
    final h = HijriCalendar()
      ..hYear = year
      ..hMonth = month
      ..hDay = day.clamp(1, 30);
    final g = h.hijriToGregorian(year, month, day.clamp(1, 29));
    return ReviewItemEntity(
      id: id,
      gregorianDate: g,
      hijriDay: day,
      hijriMonthName: _monthNames[month],
      rangeLabel: range,
      versesCount: verses,
      status: status,
    );
  }
}
