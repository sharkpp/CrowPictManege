import 'dart:io';

import 'package:crowexif/crowexif.dart';
import 'package:path/path.dart' as p;

import '../domain/models.dart';
import '../domain/track.dart';

/// crowexif によるトラックログ（SPEC FR-E4-4、§7.1）。
///
/// GPX / KML / NMEA の読み分けと補間は crowexif が行う。ここは crowexif の
/// 型をドメインの形へ移すだけに留める。
class CrowexifTrackLog implements TrackLog {
  CrowexifTrackLog(this._track, {required this.name});

  /// ファイルから読む。読めない・位置が 1 点も無い場合も、そのまま返して
  /// 件数 0 として扱う。理由は呼ぶ側が画面に出す。
  static Future<CrowexifTrackLog> load(String path) async {
    final text = await File(path).readAsString();
    return CrowexifTrackLog(GpsTrack.parse(text), name: p.basename(path));
  }

  final GpsTrack _track;

  @override
  final String name;

  @override
  int get pointCount => _track.points.length;

  @override
  DateTime? get start =>
      _track.points.isEmpty ? null : _track.points.first.time;

  @override
  DateTime? get end => _track.points.isEmpty ? null : _track.points.last.time;

  @override
  GeoPoint? at(DateTime utc, {required Duration tolerance}) {
    final fix = _track.at(utc, maxDistance: tolerance).fix;
    if (fix == null) return null;
    return GeoPoint(
      latitude: fix.latitude,
      longitude: fix.longitude,
      altitude: fix.altitude,
    );
  }
}
