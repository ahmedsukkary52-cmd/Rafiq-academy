import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../models/calendar_model.dart';
import 'calendar_remote_datasource.dart';

const String kCalendarSignedOutMessage = 'انتهت الجلسة، سجّل الدخول مرة أخرى';
const String kCalendarAddEventFailedMessage = 'تعذر إضافة الحدث، حاول مرة أخرى';

/// User-facing text for a failed event create; never the raw exception.
String calendarAddEventErrorMessage(String code) => switch (code) {
  'permission-denied' => 'ليس لديك صلاحية لإضافة أحداث لهذا التقويم',
  'unauthenticated' => kCalendarSignedOutMessage,
  'unavailable' || 'deadline-exceeded' =>
    'تعذر الاتصال بالخادم، تحقق من الإنترنت وحاول مرة أخرى',
  _ => kCalendarAddEventFailedMessage,
};

@LazySingleton(as: CalendarRemoteDatasource)
class CalendarRemoteDatasourceImpl implements CalendarRemoteDatasource {
  final FirebaseFirestore firestore;

  const CalendarRemoteDatasourceImpl({required this.firestore});

  CollectionReference get _eventsRef =>
      firestore.collection(FirestoreCollections.calendarEvents);

  @override
  Future<List<CalendarEventModel>> getMonthEvents({
    required DateTime month,
    String? halaqaId,
  }) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);

      var query = _eventsRef
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end));

      // لو محددين حلقة، نجيب أحداثها + الأحداث العامة (halaqaId == null)
      // Firestore مش بتدعم OR على حقلين مختلفين، فبنعمل قراءتين ونجمعهم
      if (halaqaId != null) {
        final halaqaSnap = await query
            .where('halaqaId', isEqualTo: halaqaId)
            .get();

        final generalSnap = await query.where('halaqaId', isNull: true).get();

        final all = {...halaqaSnap.docs, ...generalSnap.docs};

        return all.map(CalendarEventModel.fromFirestore).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
      }

      final snap = await query.orderBy('date').get();
      return snap.docs.map(CalendarEventModel.fromFirestore).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> addEvent(CalendarEventModel event) async {
    final uid =
        FirebaseAuth.instanceFor(app: firestore.app).currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw const ServerException(kCalendarSignedOutMessage);
    }
    try {
      await _eventsRef.add(event.toCreateData(creatorUid: uid));
    } on FirebaseException catch (e) {
      throw ServerException(calendarAddEventErrorMessage(e.code));
    } catch (_) {
      throw const ServerException(kCalendarAddEventFailedMessage);
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _eventsRef.doc(eventId).delete();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
