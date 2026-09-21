import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/domain/path_template.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset asset({
  String path = '/root/IMG_0001.JPG',
  DateTime? capturedAt,
  String? make = 'FUJIFILM',
  String? model = 'X-T5',
  String? lens,
  AssetKind kind = AssetKind.image,
}) =>
    MediaAsset(
      path: path,
      name: path.split('/').last,
      kind: kind,
      size: 1000,
      fileModifiedAt: DateTime(2023, 12, 31, 23, 59, 58),
    ).withSummary(
      AssetSummary(
        fileType: 'JPEG',
        capturedAt: capturedAt == null
            ? null
            : CapturedAt(
                wallClock: capturedAt,
                source: TimeSource.exifDateTimeOriginal,
              ),
        camera: CameraInfo(make: make, model: model, lens: lens),
      ),
    );

/// 出力先のひな型の展開（SPEC FR-S2、NFR-8）。
void main() {
  test('撮影時刻とファイル名で広げる', () {
    expect(
      expandTemplate(
        defaultPathTemplate,
        TemplateContext(asset(capturedAt: DateTime(2024, 3, 10, 14, 5, 6))),
      ),
      '2024/03/IMG_0001.jpg',
    );
  });

  test('時分秒・機材・種別も使える', () {
    expect(
      expandTemplate(
        '{kind}/{make}/{model}/{YYYY}{MM}{DD}_{HH}{mm}{ss}.{ext}',
        TemplateContext(asset(capturedAt: DateTime(2024, 3, 10, 14, 5, 6))),
      ),
      'image/FUJIFILM/X-T5/20240310_140506.jpg',
    );
  });

  test('撮影時刻を読めない対象はファイル更新時刻で広げる', () {
    expect(
      expandTemplate(
        '{YYYY}/{MM}/{DD}/{basename}.{ext}',
        TemplateContext(asset()),
      ),
      '2023/12/31/IMG_0001.jpg',
    );
  });

  test('値が無ければ空になり、段ごと畳まれる', () {
    expect(
      expandTemplate(
        '{YYYY}/{lens}/{basename}.{ext}',
        TemplateContext(asset(capturedAt: DateTime(2024, 3, 10))),
      ),
      '2024/IMG_0001.jpg',
    );
  });

  test('代替値を指定できる', () {
    expect(
      expandTemplate(
        '{model:unknown}/{lens:no-lens}/{basename}.{ext}',
        TemplateContext(asset(model: null)),
      ),
      'unknown/no-lens/IMG_0001.jpg',
    );
  });

  test('位置クラスタ名・セッション連番・連番を渡せる', () {
    expect(
      expandTemplate(
        '{place}/{session}/{seq}_{basename}.{ext}',
        TemplateContext(asset(), place: '京都', session: 2, seq: 7),
      ),
      '京都/2/7_IMG_0001.jpg',
    );
  });

  test('値に入った区切り文字は名前に使える形へ均す', () {
    expect(
      expandTemplate(
        '{model}/{basename}.{ext}',
        TemplateContext(asset(model: 'ILCE-7M4 / A7 IV')),
      ),
      'ILCE-7M4 _ A7 IV/IMG_0001.jpg',
    );
  });

  test('末尾の空白と点は落とす（Windows の名前に使えないため）', () {
    expect(
      expandTemplate(
        '{model}/{basename}.{ext}',
        TemplateContext(asset(model: 'X-T5 ')),
      ),
      'X-T5/IMG_0001.jpg',
    );
  });

  test('知らない名前はそのまま残す', () {
    expect(
      expandTemplate('{rating}/{basename}.{ext}', TemplateContext(asset())),
      '{rating}/IMG_0001.jpg',
    );
  });

  test('動画は種別が変わる', () {
    expect(
      expandTemplate(
        '{kind}/{basename}.{ext}',
        TemplateContext(asset(path: '/root/clip.MP4', kind: AssetKind.video)),
      ),
      'video/clip.mp4',
    );
  });
}
