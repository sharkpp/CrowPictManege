/// Exif の Orientation（1〜8）を、回転と鏡映に分ける。
///
/// 値は「保存されている向きを、正しい向きへ直すための操作」を表す。
/// 回転を先に、鏡映を後に適用する。
({int quarterTurns, bool mirrored}) orientationTransform(int? orientation) =>
    switch (orientation) {
      2 => (quarterTurns: 0, mirrored: true),
      3 => (quarterTurns: 2, mirrored: false),
      4 => (quarterTurns: 2, mirrored: true),
      5 => (quarterTurns: 1, mirrored: true),
      6 => (quarterTurns: 1, mirrored: false),
      7 => (quarterTurns: 3, mirrored: true),
      8 => (quarterTurns: 3, mirrored: false),
      _ => (quarterTurns: 0, mirrored: false),
    };

/// 縦横が入れ替わる向きかどうか。表示上の縦横比を出すのに使う。
bool orientationSwapsAxes(int? orientation) =>
    orientationTransform(orientation).quarterTurns.isOdd;
