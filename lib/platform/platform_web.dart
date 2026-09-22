import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

import '../adapters/crowexif_bytes_metadata.dart';
import '../adapters/web_directory_source.dart';
import '../ports/asset_source_port.dart';
import '../ports/file_ops_port.dart';
import '../ports/metadata_port.dart';
import '../ports/metadata_write_port.dart';
import '../ports/transfer_port.dart';
import '../ports/watcher_port.dart';
import 'capabilities.dart';

/// Web でできること（SPEC §8）。
///
/// できない機能は画面から隠さず、理由を添えて無効にする。
const platformCapabilities = PlatformCapabilities(
  folderPicker: true,
  // 許可ディレクトリ内への書き戻しは W4 で入れる。
  writeMetadata: false,
  setFileTimes: false,
  exportFiles: false,
  transferToApps: false,
  watchFolders: false,
  // ブラウザはパスからファイルを開けない。バイト列を読んでから復号する。
  decodeFromPath: false,
  dropOntoWindow: false,
  dragOut: false,
  saveToFile: false,
  // Isolate が無い。走査も復号も 1 本のスレッドで行う（SPEC §7.3）。
  parallel: false,
  // ブラウザの再生器は 1 コマ送りを持たない。
  videoFrameStep: false,
);

/// 取得元は 1 つだけ持つ。
///
/// 開いたフォルダのハンドルはこの中にある。選ぶ側と走査する側で別の実体を
/// 持つと、選んだフォルダを走査できない。
final _source = WebDirectorySource();

AssetSourcePort createAssetSource() => _source;

MetadataPort createMetadataPort() => CrowexifBytesMetadata(_source);

MetadataWritePort? createMetadataWriter({
  String? backupDirectory,
  int backupGenerations = 3,
}) => null;

FileOpsPort? createFileOps() => null;

TransferPort? createTransferPort() => null;

WatcherPort? createWatcherPort() => null;

/// カタログの置き場所（SPEC §4.4）。ブラウザの保存領域に置く。
///
/// `web/sqlite3.wasm` と `web/drift_worker.js` を読む。どちらも配布物に含める。
QueryExecutor openCatalogExecutor() => LazyDatabase(() async {
  final result = await WasmDatabase.open(
    databaseName: 'catalog',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  return result.resolvedExecutor;
});

/// ブラウザにはアプリ領域のフォルダが無い。控えは取れない（SPEC §8）。
Future<String?> defaultBackupDirectory() async => null;

/// 開くフォルダを選ばせる（SPEC FR-B1）。
Future<String?> pickDirectory({String? confirmText}) => _source.pickDirectory();

/// ブラウザの再生器は 1 コマ送りを持たない（SPEC §8）。
Future<void> stepVideoFrame(Player player, {required bool forward}) async {}

/// ブラウザはパスでファイルを開けない。読んだバイト列から出す（SPEC §8）。
ImageProvider? imageProviderFor(String path) => null;

/// ブラウザは別のアプリを起こせない（SPEC §8）。
Future<String?> pickApplication({String? confirmText}) async => null;

/// 任意の場所への書き出しは W4 で入れる。
Future<bool> saveTextFile({
  required String suggestedName,
  required String text,
  required List<XTypeGroup> types,
}) async => false;
