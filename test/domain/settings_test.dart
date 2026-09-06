import 'package:crow_pict_manege/domain/pinned_fields.dart';
import 'package:crow_pict_manege/domain/settings.dart';
import 'package:crow_pict_manege/domain/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

/// 設定の符号化・復号（SPEC FR-P1）。
void main() {
  test('保存して読み直すと同じ設定になる', () {
    const settings = AppSettings(
      folderMode: FolderMode.folders,
      folderThumbnails: 2,
      viewMode: ViewMode.gallery,
      sortMode: SortMode.name,
      tileSize: 220,
    );

    final restored = AppSettings.fromMap(settings.toMap());

    expect(restored.folderMode, FolderMode.folders);
    expect(restored.folderThumbnails, 2);
    expect(restored.viewMode, ViewMode.gallery);
    expect(restored.sortMode, SortMode.name);
    expect(restored.tileSize, 220);
  });

  test('地図と転送先も保存して読み直せる（SPEC FR-M7、FR-M8、FR-T3）', () {
    const settings = AppSettings(
      tileUrl: 'https://tiles.example/{z}/{x}/{y}.png',
      geocodingEnabled: true,
      geocodingEndpoint: 'https://places.example',
      transferTargets: [
        TransferTarget(name: '現像', command: '/Applications/RAW.app'),
      ],
    );

    final restored = AppSettings.fromMap(settings.toMap());

    expect(restored.tileUrl, 'https://tiles.example/{z}/{x}/{y}.png');
    expect(restored.geocodingEnabled, isTrue);
    expect(restored.geocodingEndpoint, 'https://places.example');
    expect(restored.transferTargets.single.name, '現像');
  });

  test('地名の引き当ては既定で止まっている（SPEC NFR-5）', () {
    const settings = AppSettings();
    expect(settings.geocodingEnabled, isFalse);
    expect(AppSettings.fromMap(const {}).geocodingEnabled, isFalse);
  });

  test('地図タイルの取得先が空なら既定へ戻す', () {
    final settings = AppSettings.fromMap(const {'tileUrl': ''});
    expect(settings.tileUrl, AppSettings.defaultTileUrl);
  });

  test('保存が無ければ既定値になる', () {
    final settings = AppSettings.fromMap(const {});
    expect(settings.folderMode, FolderMode.flat);
    expect(settings.folderThumbnails, 4);
    expect(settings.viewMode, ViewMode.grid);
  });

  test('壊れた値・知らない値は既定値に落ちる', () {
    final settings = AppSettings.fromMap(const {
      'folderMode': 'なにか',
      'folderThumbnails': '数値ではない',
      'viewMode': 'timeline',
    });
    expect(settings.folderMode, FolderMode.flat);
    expect(settings.folderThumbnails, 4);
    expect(settings.viewMode, ViewMode.grid);
  });

  test('範囲外の値は範囲へ丸める', () {
    final settings = AppSettings.fromMap(const {
      'folderThumbnails': '99',
      'tileSize': '4000',
    });
    expect(settings.folderThumbnails, AppSettings.maxFolderThumbnails);
    expect(settings.tileSize, 320);
  });

  test('ピン留めした項目も保存される', () {
    const settings = AppSettings(pinned: ['EXIF:Make', 'Summary:location']);
    expect(AppSettings.fromMap(settings.toMap()).pinned, [
      'EXIF:Make',
      'Summary:location',
    ]);
  });

  test('ピン留めを全部外した状態も保てる', () {
    const settings = AppSettings(pinned: []);
    expect(AppSettings.fromMap(settings.toMap()).pinned, isEmpty);
  });

  test('保存が無ければ既定のピン留めになる', () {
    expect(AppSettings.fromMap(const {}).pinned, defaultPinnedKeys);
  });

  test('古い形のピン留めは読まず、既定に戻す', () {
    // キーが画面の言葉だった頃の値。読み替えずに捨てる（AGENTS.md）。
    expect(
      AppSettings.fromMap(const {'pinned': '要約:撮影時刻,要約:位置'}).pinned,
      defaultPinnedKeys,
    );
  });
}
