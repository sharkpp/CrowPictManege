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
  domain/    I/O を持たない業務ロジック（時刻・GPS の正規化、列とフィルタ、
             フォルダ表示、検索の判定、知覚ハッシュ、設定の符号化）
  ports/     プラットフォームに依存しない抽象インタフェース（メタ情報、カタログ）
  adapters/  ポートの実装（crowexif、ファイルシステム、SQLite のカタログ）
  services/  並列読み取り、サムネイルキャッシュ、検索、類似画像
  state/     画面の状態（Riverpod）
  ui/        画面
```

カタログ（設定・ブックマーク・履歴・メタ情報とサムネイルのキャッシュ）は
アプリ領域の `catalog.sqlite` に置く。drift のテーブル定義から
`catalog_database.g.dart` を生成しているので、テーブルを変えたら次を実行する。

```console
$ dart run build_runner build
```

## いまできること

- フォルダを開く（ダイアログ、ドロップ、パンくず、履歴、ブックマーク）
- 表示モード: サムネイル／リスト／ギャラリー／マップ
- 下位フォルダの扱いを展開／フォルダ表示で切り替え、フォルダに下位サムネイルを重ねる
- リストの列の並べ替え・表示切替・幅、および列ごとのフィルタ
- メタ情報の閲覧（要約＋全タグ）、複数選択時の共通値表示、コピー
- 検索: ファイル名／メタ情報（現在のフォルダとブックマークを範囲に選択）
- 類似画像検索（1 枚／複数枚を種に、知覚ハッシュの距離で）

## 開発

```console
$ flutter pub get
$ flutter test
$ flutter run -d macos
```

crowexif を `../crowexif` に置いておく必要がある。

## ライセンス

Copyright (c) sharkpp
