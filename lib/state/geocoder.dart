import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/nominatim_geocoder.dart';
import '../domain/models.dart';
import '../ports/geocoder_port.dart';
import 'settings.dart';

/// 地名を引く相手（SPEC FR-M5、FR-M8）。
///
/// 設定で有効にしていなければ null を返す。座標を外へ出す機能なので、
/// 既定では相手を作らない（SPEC NFR-5）。
final geocoderProvider = Provider<GeocoderPort?>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.geocodingEnabled) return null;
  return NominatimGeocoder(endpoint: settings.geocodingEndpoint);
});

/// 逆引きの鍵。10 m ほどの違いは同じ場所として扱い、何度も引かない。
String placeKeyOf(GeoPoint point) =>
    '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';

/// 座標から引いた地名（SPEC FR-M8）。鍵は [placeKeyOf] が作る。
final placeNameProvider = FutureProvider.family<String?, String>((
  ref,
  key,
) async {
  final geocoder = ref.watch(geocoderProvider);
  if (geocoder == null) return null;
  final parts = key.split(',');
  if (parts.length != 2) return null;
  final latitude = double.tryParse(parts[0]);
  final longitude = double.tryParse(parts[1]);
  if (latitude == null || longitude == null) return null;
  return geocoder.describe(GeoPoint(latitude: latitude, longitude: longitude));
});
