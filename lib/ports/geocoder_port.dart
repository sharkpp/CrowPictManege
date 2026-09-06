import '../domain/models.dart';

/// 地名の検索で見つかった 1 か所（SPEC FR-M5）。
class PlaceMatch {
  const PlaceMatch({required this.name, required this.point});

  /// 人が読む地名。相手が返した文字をそのまま出す。
  final String name;
  final GeoPoint point;
}

/// 地名を引く相手（SPEC FR-M5、FR-M8）。
///
/// これを使うと座標や地名が外部へ出る。既定では無効にし、使うときだけ
/// 有効にする（SPEC NFR-5）。
abstract interface class GeocoderPort {
  /// 地名・住所から場所を探す（SPEC FR-M5）。
  Future<List<PlaceMatch>> search(String query);

  /// 座標から地名を引く（SPEC FR-M8）。分からなければ null。
  Future<String?> describe(GeoPoint point);
}
