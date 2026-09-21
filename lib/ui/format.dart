import 'package:intl/intl.dart';

import '../domain/grouping.dart';
import '../domain/models.dart';
import '../l10n/l10n.dart';
import 'labels.dart';

/// 書式は言葉と同じく `lib/l10n/*.arb` で決める（SPEC NFR-7）。
/// 一覧では 1 行ごとに呼ばれるので、組み立てた `DateFormat` は使い回す。
final _formats = <String, DateFormat>{};

DateFormat _format(String pattern) =>
    _formats.putIfAbsent(pattern, () => DateFormat(pattern));

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

String formatCoordinates(GeoPoint point) =>
    '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';

extension AppFormats on AppLocalizations {
  String formatCapturedAt(CapturedAt? captured, {bool short = false}) {
    if (captured == null) return '—';
    final pattern = short ? dateTimeShortPattern : dateTimePattern;
    final offset = captured.offset;
    final text = _format(pattern).format(captured.wallClock);
    return offset == null ? text : '$text ${formatOffset(offset)}';
  }

  /// 撮影時刻をどう決めたかの説明（SPEC §4.2）。
  String describeTimeBasis(CapturedAt captured) {
    final offset = captured.offset == null
        ? offsetUnknown
        : offsetWithSource(offsetSourceLabel(captured.offsetSource));
    return '${timeSourceLabel(captured.source)} / $offset';
  }

  /// 履歴の「いつ訪れたか」を短く表す。
  String formatRelativeTime(DateTime at) {
    final elapsed = DateTime.now().difference(at);
    if (elapsed.inMinutes < 1) return relativeJustNow;
    if (elapsed.inHours < 1) return relativeMinutes(elapsed.inMinutes);
    if (elapsed.inDays < 1) return relativeHours(elapsed.inHours);
    if (elapsed.inDays < 30) return relativeDays(elapsed.inDays);
    return formatDateTime(at);
  }

  /// ファイル更新時刻などの素の日時。
  String formatDateTime(DateTime value) =>
      _format(dateTimeShortPattern).format(value);

  /// 日付だけを出す（絞り込みの範囲など）。
  String formatDate(DateTime value) => _format(datePattern).format(value);

  /// まとまりの見出しに出す言葉（SPEC FR-G1、NFR-7）。
  ///
  /// まとまりは識別子と代表値だけを持つ。言葉にするのはここだけにする。
  String groupHeading(AssetGroup group) {
    final time = group.time;
    if (group.isUnset && group.key != GroupKey.session) return groupUnset;
    return switch (group.key) {
      GroupKey.year when time != null => _format(groupYearPattern).format(time),
      GroupKey.month when time != null => _format(
        groupMonthPattern,
      ).format(time),
      GroupKey.day when time != null => formatDate(time),
      GroupKey.hour when time != null => _format(groupHourPattern).format(time),
      GroupKey.session => [
        groupSessionLabel(group.ordinal ?? 0),
        if (time != null) formatDateTime(time),
      ].join(' '),
      GroupKey.place => [
        groupPlaceLabel(group.ordinal ?? 0),
        if (group.center != null) formatCoordinates(group.center!),
      ].join(' '),
      GroupKey.kind => assetKindNameLabel(group.id),
      _ => group.id,
    };
  }
}
