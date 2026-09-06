import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_info.dart';
import '../domain/models.dart';
import '../ports/geocoder_port.dart';

/// Nominatim（OpenStreetMap）による地名の検索と逆引き（SPEC FR-M5、FR-M8）。
///
/// 公開の相手には作法がある。名乗り（User-Agent）を必ず付け、1 度の操作につき
/// 1 回だけ呼ぶ。連続して引かないよう、呼ぶ側で結果を持っておく。
class NominatimGeocoder implements GeocoderPort {
  NominatimGeocoder({required this.endpoint, http.Client? client})
    : _client = client ?? http.Client();

  final String endpoint;
  final http.Client _client;

  /// 一度に返す件数。選ばせるのに足りて、読み切れる数にする。
  static const _limit = 5;

  @override
  Future<List<PlaceMatch>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final body = await _get('/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '$_limit',
    });
    if (body is! List) return const [];
    return [
      for (final entry in body)
        if (entry is Map) ?_matchOf(entry),
    ];
  }

  @override
  Future<String?> describe(GeoPoint point) async {
    final body = await _get('/reverse', {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'jsonv2',
    });
    if (body is! Map) return null;
    final name = body['display_name'];
    return name is String && name.isNotEmpty ? name : null;
  }

  PlaceMatch? _matchOf(Map<Object?, Object?> entry) {
    final latitude = double.tryParse('${entry['lat']}');
    final longitude = double.tryParse('${entry['lon']}');
    final name = entry['display_name'];
    if (latitude == null || longitude == null || name is! String) return null;
    return PlaceMatch(
      name: name,
      point: GeoPoint(latitude: latitude, longitude: longitude),
    );
  }

  Future<Object?> _get(String path, Map<String, String> query) async {
    final base = Uri.parse(endpoint);
    final uri = base.replace(
      path: '${base.path}$path'.replaceAll('//', '/'),
      queryParameters: query,
    );
    final response = await _client.get(
      uri,
      headers: {
        'User-Agent': '$appIdentifier/$appVersion',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }
}
