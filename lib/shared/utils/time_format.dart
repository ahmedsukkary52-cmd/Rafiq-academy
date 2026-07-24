/// Shared clock / duration formatting for presentation widgets.
library;

/// `MM:SS` using total minutes (may exceed 59).
String formatDurationMmSs(Duration duration) {
  final m = duration.inMinutes.toString().padLeft(2, '0');
  final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// `MM:SS` from a whole-second count.
String formatSecondsMmSs(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 24-hour `HH:mm`.
String formatTimeHm24(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// 12-hour clock with Arabic ص/م, e.g. `3:05 م`.
String formatTimeHm12Ar(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'ص' : 'م';
  return '$hour:$minute $period';
}

/// `YYYY/MM/DD`.
String formatDateYmd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}/$m/$day';
}

/// `DD/MM/YYYY`.
String formatDateDmy(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final m = d.month.toString().padLeft(2, '0');
  return '$day/$m/${d.year}';
}
