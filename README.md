# CrowPictManege

画像・動画のメタ情報を一覧・閲覧・編集するアプリケーション。
撮影時刻と GPS 情報の修正を容易にすることを中核とする。

仕様は [SPEC.md](SPEC.md) を参照。

## 構成

- Flutter / Dart。Windows・macOS・iOS・Android・Web を単一のコードベースで対象とする。
- メタ情報の読み書きは [crowexif](https://github.com/sharkpp/crowexif)（pure Dart）に一本化する。
  隣に置いた作業コピーを `path` 依存で参照する。

```
lib/
  domain/    I/O を持たない業務ロジック（時刻正規化・GPS 正規化・対応形式）
  ports/     プラットフォームに依存しない抽象インタフェース
  adapters/  ポートの実装（crowexif、ファイルシステム）
  services/  並列読み取り、サムネイルキャッシュ
  state/     画面の状態（Riverpod）
  ui/        画面
```

## 開発

```console
$ flutter pub get
$ flutter test
$ flutter run -d macos
```

crowexif を `../crowexif` に置いておく必要がある。

## ライセンス

Copyright (c) sharkpp
