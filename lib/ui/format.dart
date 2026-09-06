import 'package:intl/intl.dart';

import '../domain/models.dart';
import 'labels.dart';

final _dateTime = DateFormat('yyyy/MM/dd HH:mm:ss');
final _dateTimeShort = DateFormat('yyyy/MM/dd HH:mm');

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// オフセットを `+09:00` の形にする。
String formatOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = absolute.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '$sign$hours:$minutes';
}

String formatCapturedAt(CapturedAt? captured, {bool short = false}) {
  if (captured == null) return '—';
  final format = short ? _dateTimeShort : _dateTime;
  final offset = captured.offset;
  final text = format.format(captured.wallClock);
  return offset == null ? text : '$text ${formatOffset(offset)}';
}

/// 撮影時刻をどう決めたかの説明（SPEC §4.2）。
String describeTimeBasis(CapturedAt captured) {
  final offset = captured.offset == null
      ? 'オフセット不明'
      : 'オフセット: ${offsetSourceLabel(captured.offsetSource)}';
  return '${timeSourceLabel(captured.source)} / $offset';
}

String formatCoordinates(GeoPoint point) =>
    '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';

/// 履歴の「いつ訪れたか」を短く表す。
String formatRelativeTime(DateTime at) {
  final elapsed = DateTime.now().difference(at);
  if (elapsed.inMinutes < 1) return 'たった今';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} 分前';
  if (elapsed.inDays < 1) return '${elapsed.inHours} 時間前';
  if (elapsed.inDays < 30) return '${elapsed.inDays} 日前';
  return _dateTimeShort.format(at);
}

/// ファイル更新時刻などの素の日時。
String formatDateTime(DateTime value) => _dateTimeShort.format(value);
