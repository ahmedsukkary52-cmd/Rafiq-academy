import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../models/calendar_model.dart';
import 'calendar_remote_datasource.dart';

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
    try {
      await _eventsRef.add(event.toFirestore());
    } catch (e) {
      throw ServerException(e.toString());
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
