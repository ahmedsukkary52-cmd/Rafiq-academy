/// How [getHalaqaRecitationRecords] loads Firestore rows.
///
/// [fullHistory] pages by document id until exhausted (includes docs missing
/// `date`). Required for readiness counts and evaluation history.
///
/// [newestByDate] uses `orderBy(date desc).limit` — one bounded read. Firestore
/// omits documents that lack `date`. Supported write paths set `date`; this mode
/// is display-only and must not drive pending-review counts.
enum RecitationRecordsQueryMode {
  fullHistory,
  newestByDate,
}
