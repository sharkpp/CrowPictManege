/// 座標の読み取りと距離（SPEC FR-E4-1、FR-F2、FR-G4）。
///
/// 十進度と度分秒の双方を受け取る。半球は文字でも符号でも示せる。
library;

import 'dart:math' as math;

import 'models.dart';

final _decimalPattern = RegExp(r'^([+-]?\d+(?:\.\d+)?)$');

final _dmsPattern = RegExp(
  r'^([NSEW])?\s*'
  r'([+-]?\d+(?:\.\d+)?)\s*(?:°|deg)?\s*'
  r"(?:(\d+(?:\.\d+)?)\s*(?:′|')?\s*)?"
  r'(?:(\d+(?:\.\d+)?)\s*(?:″|")?\s*)?'
  r'([NSEW])?$',
  caseSensitive: false,
);

/// 十進度・度分秒のどちらでも読む。読めなければ null。
///
/// `35.681236` `35 40 52.4 N` `N35°40'52.4"` `-33.8688` を受け取る。
///
/// 度分秒の単位は記号と `deg` だけを認める。`s` のような 1 文字の単位は
/// 半球の文字と見分けが付かない。
double? parseCoordinate(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final decimal = _decimalPattern.firstMatch(trimmed);
  if (decimal != null) return double.parse(decimal.group(1)!);

  final match = _dmsPattern.firstMatch(trimmed);
  if (match == null) return null;

  final degrees = double.parse(match.group(2)!);
  final minutes = double.tryParse(match.group(3) ?? '') ?? 0;
  final seconds = double.tryParse(match.group(4) ?? '') ?? 0;
  if (minutes >= 60 || seconds >= 60) return null;

  // 半球は前後どちらに書かれていてもよい。両方あるものは読まない。
  final before = match.group(1)?.toUpperCase();
  final after = match.group(5)?.toUpperCase();
  if (before != null && after != null) return null;
  final hemisphere = before ?? after;

  final magnitude = degrees.abs() + minutes / 60 + seconds / 3600;
  final negative = degrees.isNegative || hemisphere == 'S' || hemisphere == 'W';
  return negative ? -magnitude : magnitude;
}

/// 緯度として妥当か。
bool isLatitude(double value) => value.abs() <= 90;

/// 経度として妥当か。
bool isLongitude(double value) => value.abs() <= 180;

/// 地球の半径（m）。距離は球として求める。
const _earthRadius = 6371008.8;

/// 2 点間の距離（m）。
///
/// 数 km から数百 km までを扱えれば足りるので、回転楕円体ではなく球で求める
/// （SPEC FR-F2 の「指定座標からの距離」、FR-G4 の位置クラスタ）。
double distanceInMeters(GeoPoint a, GeoPoint b) {
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final deltaLat = lat2 - lat1;
  final deltaLon = _radians(b.longitude - a.longitude);

  final h =
      math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(deltaLon / 2) *
          math.sin(deltaLon / 2);
  return 2 * _earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

double _radians(double degrees) => degrees * math.pi / 180;
