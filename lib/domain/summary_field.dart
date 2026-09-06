/// 要約に出す派生値の種類（SPEC FR-V2）。
///
/// どれをピン留めしたかは設定に残る（SPEC FR-P7）。残すのは [id] であり、
/// 画面に出す言葉ではない。言葉は表示側で決める（SPEC NFR-7）。
enum SummaryField {
  name('name'),
  kind('kind'),
  capturedAt('capturedAt'),
  timeBasis('timeBasis'),
  location('location'),
  altitude('altitude'),
  camera('camera'),
  lens('lens'),
  dimensions('dimensions'),
  duration('duration'),
  fileType('fileType'),
  size('size');

  const SummaryField(this.id);

  /// 設定に残す識別子。表示の言葉が変わっても動かさない。
  final String id;

  static SummaryField? byId(String id) {
    for (final field in values) {
      if (field.id == id) return field;
    }
    return null;
  }
}
