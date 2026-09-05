import 'package:crow_pict_manege/domain/pinned_fields.dart';
import 'package:crow_pict_manege/domain/settings.dart';
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
    const settings = AppSettings(pinned: ['EXIF:Make', '要約:位置']);
    expect(AppSettings.fromMap(settings.toMap()).pinned, ['EXIF:Make', '要約:位置']);
  });

  test('ピン留めを全部外した状態も保てる', () {
    const settings = AppSettings(pinned: []);
    expect(AppSettings.fromMap(settings.toMap()).pinned, isEmpty);
  });

  test('保存が無ければ既定のピン留めになる', () {
    expect(AppSettings.fromMap(const {}).pinned, defaultPinnedKeys);
  });
}
