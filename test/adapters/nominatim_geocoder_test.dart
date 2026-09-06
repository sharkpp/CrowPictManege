import 'dart:convert';

import 'package:crow_pict_manege/adapters/nominatim_geocoder.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 地名の検索と逆引き（SPEC FR-M5、FR-M8）。
///
/// 相手には出さない。送る形と受け取った値の読み方だけを固定する。
void main() {
  late List<http.Request> sent;

  NominatimGeocoder geocoderReturning(Object body) {
    sent = [];
    return NominatimGeocoder(
      endpoint: 'https://places.example/api',
      client: MockClient((request) async {
        sent.add(request);
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }

  test('地名から場所を探す', () async {
    final geocoder = geocoderReturning([
      {'lat': '35.6812', 'lon': '139.7671', 'display_name': '東京駅'},
      {'lat': '34.7025', 'lon': '135.4959', 'display_name': '大阪駅'},
    ]);

    final matches = await geocoder.search('駅');

    expect(matches, hasLength(2));
    expect(matches.first.name, '東京駅');
    expect(matches.first.point.latitude, closeTo(35.6812, 0.0001));
    expect(sent.single.url.path, '/api/search');
    expect(sent.single.url.queryParameters['q'], '駅');
    expect(
      sent.single.headers['User-Agent'],
      contains('net.sharkpp.crowpictmanege'),
      reason: '公開の相手には名乗る',
    );
  });

  test('読めない項目は落とす', () async {
    final geocoder = geocoderReturning([
      {'lat': 'いいかげん', 'lon': '139.7', 'display_name': '駄目'},
      {'lat': '35.0', 'lon': '139.0', 'display_name': '良い'},
    ]);

    final matches = await geocoder.search('駅');
    expect(matches.map((match) => match.name), ['良い']);
  });

  test('探す言葉が空なら相手を呼ばない', () async {
    final geocoder = geocoderReturning(const []);
    expect(await geocoder.search('   '), isEmpty);
    expect(sent, isEmpty);
  });

  test('座標から地名を引く', () async {
    final geocoder = geocoderReturning({'display_name': '東京都千代田区'});

    final name = await geocoder.describe(
      const GeoPoint(latitude: 35.68, longitude: 139.76),
    );

    expect(name, '東京都千代田区');
    expect(sent.single.url.path, '/api/reverse');
    expect(sent.single.url.queryParameters['lat'], '35.68');
  });

  test('相手が断ったら黙って諦める', () async {
    final geocoder = NominatimGeocoder(
      endpoint: 'https://places.example',
      client: MockClient((request) async => http.Response('no', 429)),
    );

    expect(await geocoder.search('駅'), isEmpty);
    expect(
      await geocoder.describe(const GeoPoint(latitude: 0, longitude: 0)),
      isNull,
    );
  });
}
