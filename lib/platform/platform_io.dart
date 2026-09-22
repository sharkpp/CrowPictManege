import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../adapters/crowexif_metadata.dart';
import '../adapters/crowexif_writer.dart';
import '../adapters/desktop_file_ops.dart';
import '../adapters/desktop_transfer.dart';
import '../adapters/desktop_watcher.dart';
import '../adapters/file_system_source.dart';
import '../ports/asset_source_port.dart';
import '../ports/file_ops_port.dart';
import '../ports/metadata_port.dart';
import '../ports/metadata_write_port.dart';
import '../ports/transfer_port.dart';
import '../ports/watcher_port.dart';
import 'capabilities.dart';

/// デスクトップ（Windows / macOS）でできること（SPEC §8）。
const platformCapabilities = PlatformCapabilities(
  folderPicker: true,
  writeMetadata: true,
  backupOriginals: true,
  setFileTimes: true,
  exportFiles: true,
  transferToApps: true,
  watchFolders: true,
  decodeFromPath: true,
  dropOntoWindow: true,
  dragOut: true,
  saveToFile: true,
  parallel: true,
  videoFrameStep: true,
);

AssetSourcePort createAssetSource() => const FileSystemSource();

MetadataPort createMetadataPort() => const CrowexifMetadata();

/// 書き込み口。書けないプラットフォームでは null（SPEC §8）。
MetadataWritePort? createMetadataWriter({
  String? backupDirectory,
  int backupGenerations = 3,
}) => CrowexifWriter(
  backupDirectory: backupDirectory,
  backupGenerations: backupGenerations,
);

FileOpsPort? createFileOps() => const DesktopFileOps();

TransferPort? createTransferPort() => const DesktopTransfer();

WatcherPort? createWatcherPort() => const DesktopWatcher();

/// カタログの置き場所。アプリ領域のファイルを開く（SPEC §4.4）。
///
/// パスの解決は最初のクエリまで遅らせる。
QueryExecutor openCatalogExecutor() => LazyDatabase(() async {
  final directory = await getApplicationSupportDirectory();
  final file = File(p.join(directory.path, 'catalog.sqlite'));
  return NativeDatabase.createInBackground(file);
});

/// 原本の控えを置く既定の場所（SPEC FR-E6-2）。
Future<String?> defaultBackupDirectory() async {
  final directory = await getApplicationSupportDirectory();
  return p.join(directory.path, 'backups');
}

/// 開くフォルダを選ばせる（SPEC FR-B1）。選ばなければ null。
Future<String?> pickDirectory({String? confirmText}) =>
    getDirectoryPath(confirmButtonText: confirmText);

/// 動画を 1 コマ進める／戻す（SPEC FR-B7）。
///
/// libmpv の frame-step / frame-back-step に載せる。逆送りは映像の作りに
/// よっては効かないことがある。効かなければ何も起きない。
Future<void> stepVideoFrame(Player player, {required bool forward}) async {
  final platform = player.platform;
  if (platform is! NativePlayer) return;
  await player.pause();
  await platform.command([forward ? 'frame-step' : 'frame-back-step']);
}

/// パスから直に復号する画像の出どころ（SPEC FR-B5）。
///
/// 原寸を展開せずに目標寸法で復号できる。開けないプラットフォームでは null。
ImageProvider? imageProviderFor(String path) => FileImage(File(path));

/// 渡す先のアプリを選ばせる（SPEC FR-T2）。
///
/// macOS のアプリはフォルダなので、選ばせ方が Windows と違う。
Future<String?> pickApplication({String? confirmText}) async {
  if (Platform.isMacOS) {
    return getDirectoryPath(
      initialDirectory: '/Applications',
      confirmButtonText: confirmText,
    );
  }
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'application', extensions: ['exe']),
    ],
  );
  return file?.path;
}

/// 文字列をファイルへ書き出す（SPEC FR-V5）。書き出せなければ false。
Future<bool> saveTextFile({
  required String suggestedName,
  required String text,
  required List<XTypeGroup> types,
}) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: types,
  );
  if (location == null) return false;
  await File(location.path).writeAsString(text);
  return true;
}
