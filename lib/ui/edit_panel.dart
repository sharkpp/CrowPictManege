import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:file_selector/file_selector.dart';

import '../adapters/crowexif_track.dart';
import '../domain/coordinates.dart';
import '../domain/edit.dart';
import '../domain/models.dart';
import '../domain/normalize.dart';
import '../domain/track.dart';
import '../l10n/l10n.dart';
import '../platform/platform.dart';
import '../state/edits.dart';
import '../state/search.dart';
import '../state/settings.dart';
import '../state/selection.dart';
import 'format.dart';
import 'labels.dart';

/// 編集の作業面（SPEC §5.3）。
///
/// 操作を積み、当てたらどうなるかを見てから適用する。ファイルへ触るのは
/// 適用の時だけとする（SPEC FR-E5）。
class EditPanel extends ConsumerStatefulWidget {
  const EditPanel({super.key});

  @override
  ConsumerState<EditPanel> createState() => _EditPanelState();
}

class _EditPanelState extends ConsumerState<EditPanel> {
  final _days = TextEditingController();
  final _hours = TextEditingController();
  final _minutes = TextEditingController();
  final _seconds = TextEditingController();
  final _time = TextEditingController();
  final _timeOffset = TextEditingController();
  final _zone = TextEditingController();
  final _reference = TextEditingController();
  final _distributeStart = TextEditingController();
  final _distributeInterval = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _altitude = TextEditingController();
  final _trackShift = TextEditingController();
  final _trackTolerance = TextEditingController(
    text: '${defaultTrackTolerance.inMinutes}',
  );

  TimeZoneMode _zoneMode = TimeZoneMode.reinterpret;

  /// 読み込んだトラックログ（SPEC FR-E4-4）。積むまでファイルには触らない。
  TrackLog? _track;

  /// 読み込みの最中か。大きな記録は読むのに間がある。
  bool _loadingTrack = false;

  @override
  void dispose() {
    for (final controller in [
      _days,
      _hours,
      _minutes,
      _seconds,
      _time,
      _timeOffset,
      _zone,
      _reference,
      _distributeStart,
      _distributeInterval,
      _latitude,
      _longitude,
      _altitude,
      _trackShift,
      _trackTolerance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (ref.watch(selectionProvider).isEmpty) {
      return Center(child: Text(l10n.editSelectAssets));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _Section(
                title: l10n.editSectionTime,
                children: [
                  _shiftRow(),
                  _setTimeRow(),
                  _timeZoneRow(),
                  _referenceRow(),
                  _distributeRow(),
                  _adoptRow(),
                ],
              ),
              _Section(
                title: l10n.editSectionLocation,
                children: [_locationRows(), const Divider(), _trackRows()],
              ),
              _Section(
                title: l10n.editSectionTargets,
                children: [_destinationRow(), _targetsRow()],
              ),
              const _QueueSection(),
              const _PreviewSection(),
            ],
          ),
        ),
        const Divider(height: 1),
        const _ApplyBar(),
      ],
    );
  }

  /// 相対シフト（SPEC FR-E3-1）。前後どちらへも同じ量で動かせる。
  Widget _shiftRow() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _amount(_days, l10n.editUnitDays, 'shift-days'),
            _amount(_hours, l10n.editUnitHours, 'shift-hours'),
            _amount(_minutes, l10n.editUnitMinutes, 'shift-minutes'),
            _amount(_seconds, l10n.editUnitSeconds, 'shift-seconds'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.remove, size: 18),
                label: Text(l10n.editShiftBack),
                onPressed: () => _queueShift(-1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.editShiftForward),
                onPressed: () => _queueShift(1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ずらす量の 1 桁。単位は同じ言葉が他の欄にも出るので、鍵で見分ける。
  Widget _amount(TextEditingController controller, String unit, String key) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: TextField(
            key: Key(key),
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: unit,
              hintText: '0',
            ),
          ),
        ),
      );

  void _queueShift(int sign) {
    final delta = Duration(
      days: int.tryParse(_days.text) ?? 0,
      hours: int.tryParse(_hours.text) ?? 0,
      minutes: int.tryParse(_minutes.text) ?? 0,
      seconds: int.tryParse(_seconds.text) ?? 0,
    );
    if (delta == Duration.zero) return;
    ref.read(editQueueProvider.notifier).add(ShiftTime(delta * sign));
  }

  /// 絶対設定（SPEC FR-E3-2）。オフセットは空なら元の値を保つ。
  Widget _setTimeRow() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _time,
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            labelText: l10n.editSetTimeLabel,
            hintText: l10n.editTimeHint,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _timeOffset,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: l10n.editOffsetLabel,
                  hintText: l10n.editOffsetHint,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _AddButton(
              key: const Key('queue-set-time'),
              onPressed: _queueSetTime,
            ),
          ],
        ),
      ],
    );
  }

  void _queueSetTime() {
    final parsed = parseMetadataDateTime(_time.text);
    if (parsed == null) {
      _complain();
      return;
    }
    final text = _timeOffset.text.trim();
    final offset = text.isEmpty ? parsed.offset : parseOffset(text);
    if (text.isNotEmpty && offset == null) {
      _complain();
      return;
    }
    ref
        .read(editQueueProvider.notifier)
        .add(SetTime(parsed.wallClock, offset: offset));
  }

  /// タイムゾーンの再解釈と変換（SPEC FR-E3-3）。
  Widget _timeZoneRow() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _zone,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: l10n.editTimeZoneLabel,
                  hintText: l10n.editOffsetHint,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _AddButton(
              key: const Key('queue-time-zone'),
              onPressed: _queueTimeZone,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<TimeZoneMode>(
          segments: [
            for (final mode in TimeZoneMode.values)
              ButtonSegment(
                value: mode,
                label: Text(l10n.timeZoneModeLabel(mode)),
                tooltip: mode == TimeZoneMode.reinterpret
                    ? l10n.editTimeZoneReinterpretHint
                    : l10n.editTimeZoneConvertHint,
              ),
          ],
          selected: {_zoneMode},
          showSelectedIcon: false,
          onSelectionChanged: (value) =>
              setState(() => _zoneMode = value.first),
        ),
      ],
    );
  }

  void _queueTimeZone() {
    final offset = parseOffset(_zone.text);
    if (offset == null) {
      _complain();
      return;
    }
    ref.read(editQueueProvider.notifier).add(SetTimeZone(offset, _zoneMode));
  }

  /// 基準合わせ（SPEC FR-E3-4）。
  ///
  /// 主対象の正しい時刻を与えると、その差分を選択集合全体へ当てる。
  Widget _referenceRow() {
    final l10n = context.l10n;
    final captured = _primaryCapturedAt();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _reference,
            enabled: captured != null,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: l10n.editReferenceLabel,
              hintText: l10n.editTimeHint,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _AddButton(
          key: const Key('queue-reference'),
          onPressed: captured == null ? null : _queueReference,
        ),
      ],
    );
  }

  CapturedAt? _primaryCapturedAt() => _primaryAsset()?.summary?.capturedAt;

  void _queueReference() {
    final captured = _primaryCapturedAt();
    final parsed = parseMetadataDateTime(_reference.text);
    if (captured == null || parsed == null) {
      _complain();
      return;
    }
    final delta = shiftToMatch(captured, parsed.wallClock);
    if (delta == Duration.zero) return;
    ref.read(editQueueProvider.notifier).add(ShiftTime(delta));
  }

  /// 連番配分（SPEC FR-E3-5）。並び順に開始時刻から間隔ごとを割り当てる。
  Widget _distributeRow() {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _distributeStart,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: l10n.editDistributeLabel,
              hintText: l10n.editTimeHint,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _distributeInterval,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: l10n.editDistributeInterval,
              suffixText: l10n.editUnitSeconds,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _AddButton(
          key: const Key('queue-distribute'),
          onPressed: _queueDistribute,
        ),
      ],
    );
  }

  void _queueDistribute() {
    final parsed = parseMetadataDateTime(_distributeStart.text);
    final seconds = int.tryParse(_distributeInterval.text.trim());
    if (parsed == null || seconds == null || seconds <= 0) {
      _complain();
      return;
    }
    ref
        .read(editQueueProvider.notifier)
        .add(
          DistributeTime(
            parsed.wallClock,
            interval: Duration(seconds: seconds),
            offset: parsed.offset,
          ),
        );
  }

  /// 他からの取り込み（SPEC FR-E3-6）。対象ごとに自分の値を使う。
  Widget _adoptRow() {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l10n.editAdoptLabel),
        for (final from in TimeAdoption.values)
          OutlinedButton(
            onPressed: () =>
                ref.read(editQueueProvider.notifier).add(AdoptTime(from)),
            child: Text(l10n.timeAdoptionLabel(from)),
          ),
      ],
    );
  }

  /// 位置の入力（SPEC FR-E4-1、FR-E4-3、FR-E4-5）。
  Widget _locationRows() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _coordinate(_latitude, l10n.editLatitude)),
            const SizedBox(width: 6),
            Expanded(child: _coordinate(_longitude, l10n.editLongitude)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _coordinate(_altitude, l10n.editAltitude)),
            const SizedBox(width: 6),
            _AddButton(
              key: const Key('queue-location'),
              onPressed: _queueLocation,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(
                  l10n.editCopyLocationFromPrimary,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _primaryLocation() == null ? null : _copyLocation,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.location_off, size: 18),
              label: Text(l10n.editClearLocation),
              onPressed: () => ref
                  .read(editQueueProvider.notifier)
                  .add(const ClearLocation()),
            ),
          ],
        ),
      ],
    );
  }

  /// トラックログとの突き合わせ（SPEC FR-E4-4）。
  ///
  /// 対象ごとに撮影時刻が違うので、当たる位置も対象ごとに違う。積むのは
  /// 「この記録から取り込む」という 1 つの操作で、当てるのは適用のとき。
  Widget _trackRows() {
    final l10n = context.l10n;
    final track = _track;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.route_outlined, size: 18),
                label: Text(
                  l10n.editLoadTrack,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _loadingTrack ? null : _chooseTrack,
              ),
            ),
          ],
        ),
        if (track != null) ...[
          const SizedBox(height: 4),
          Text(
            track.pointCount == 0
                ? l10n.editTrackEmpty(track.name)
                : l10n.editTrackLoaded(
                    track.name,
                    track.pointCount,
                    context.l10n.formatDateTime(track.start!.toLocal()),
                    context.l10n.formatDateTime(track.end!.toLocal()),
                  ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _trackShift,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: l10n.editTrackShift,
                  suffixText: l10n.editUnitSeconds,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _trackTolerance,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: l10n.editTrackTolerance,
                  suffixText: l10n.editUnitMinutes,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _AddButton(
              key: const Key('queue-track'),
              onPressed: track == null || track.pointCount == 0
                  ? null
                  : _queueTrack,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _chooseTrack() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'track',
          extensions: ['gpx', 'kml', 'nmea', 'log', 'txt'],
        ),
      ],
    );
    if (file == null) return;
    setState(() => _loadingTrack = true);
    try {
      // XFile はブラウザでも中身を読める。パスは使わない。
      final track = CrowexifTrackLog.parse(
        await file.readAsString(),
        name: file.name,
      );
      if (!mounted) return;
      setState(() => _track = track);
    } catch (_) {
      if (!mounted) return;
      setState(() => _track = null);
      _complain();
    } finally {
      if (mounted) setState(() => _loadingTrack = false);
    }
  }

  void _queueTrack() {
    final track = _track;
    if (track == null) return;
    final shift = int.tryParse(
      _trackShift.text.trim().isEmpty ? '0' : _trackShift.text.trim(),
    );
    final tolerance = int.tryParse(_trackTolerance.text.trim());
    if (shift == null || tolerance == null || tolerance <= 0) {
      _complain();
      return;
    }
    ref
        .read(editQueueProvider.notifier)
        .add(
          AdoptTrackLocation(
            track,
            shift: Duration(seconds: shift),
            tolerance: Duration(minutes: tolerance),
          ),
        );
  }

  Widget _coordinate(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      );

  /// 選択集合の主対象。基準合わせと位置の写し取りの種になる。
  MediaAsset? _primaryAsset() {
    final primary = ref.watch(selectionProvider).primary;
    if (primary == null) return null;
    for (final asset in ref.watch(displayedAssetsProvider)) {
      if (asset.path == primary) return asset;
    }
    return null;
  }

  /// 主対象の位置。選択集合へ配るための種になる（SPEC FR-E4-3）。
  GeoPoint? _primaryLocation() => _primaryAsset()?.summary?.location;

  void _copyLocation() {
    final point = _primaryLocation();
    if (point == null) return;
    setState(() {
      _latitude.text = point.latitude.toStringAsFixed(6);
      _longitude.text = point.longitude.toStringAsFixed(6);
      _altitude.text = point.altitude?.toStringAsFixed(1) ?? '';
    });
  }

  void _queueLocation() {
    final latitude = parseCoordinate(_latitude.text);
    final longitude = parseCoordinate(_longitude.text);
    if (latitude == null ||
        longitude == null ||
        !isLatitude(latitude) ||
        !isLongitude(longitude)) {
      _complain();
      return;
    }
    final altitudeText = _altitude.text.trim();
    final altitude = altitudeText.isEmpty
        ? null
        : double.tryParse(altitudeText);
    if (altitudeText.isNotEmpty && altitude == null) {
      _complain();
      return;
    }
    ref
        .read(editQueueProvider.notifier)
        .add(
          SetLocation(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
          ),
        );
  }

  /// どこへ書くか（SPEC §13）。元のファイルか、隣のサイドカーか。
  Widget _destinationRow() {
    final l10n = context.l10n;
    final destination = ref.watch(editQueueProvider).destination;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<WriteDestination>(
          segments: [
            for (final value in WriteDestination.values)
              ButtonSegment(
                value: value,
                label: Text(l10n.writeDestinationLabel(value)),
              ),
          ],
          selected: {destination},
          showSelectedIcon: false,
          onSelectionChanged: (value) =>
              ref.read(editQueueProvider.notifier).setDestination(value.first),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.writeDestinationHint(destination),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// 時刻の書き込み先（SPEC FR-E3-7）。
  ///
  /// サイドカーへ書くときは XMP しか置き場所が無い。理由を添えて選べなくする
  /// （SPEC §8 の「できない機能は隠さず、理由を添えて無効表示する」）。
  Widget _targetsRow() {
    final l10n = context.l10n;
    final queue = ref.watch(editQueueProvider);
    final sidecar = queue.destination == WriteDestination.sidecar;
    final targets = sidecar ? const {TimeTarget.xmp} : queue.timeTargets;
    return Wrap(
      spacing: 8,
      children: [
        for (final target in TimeTarget.values)
          FilterChip(
            label: Text(l10n.timeTargetLabel(target)),
            selected: targets.contains(target),
            tooltip: sidecar ? l10n.writeDestinationXmpOnly : null,
            onSelected: sidecar
                ? null
                : (selected) {
                    final next = Set.of(targets);
                    if (selected) {
                      next.add(target);
                    } else {
                      next.remove(target);
                    }
                    ref.read(editQueueProvider.notifier).setTimeTargets(next);
                  },
          ),
      ],
    );
  }

  void _complain() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(context.l10n.editInvalidValue)),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({super.key, required this.onPressed});

  /// null なら押せない。積む材料が揃っていないときに使う。
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: onPressed,
    child: Text(context.l10n.editAdd),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final child in children)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: child),
      ],
    ),
  );
}

/// 積んである操作。適用するまでファイルには触らない（SPEC §4.3）。
class _QueueSection extends ConsumerWidget {
  const _QueueSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queue = ref.watch(editQueueProvider);

    return _Section(
      title: l10n.editSectionQueue,
      children: [
        if (queue.isEmpty)
          Text(
            l10n.editQueueEmpty,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else ...[
          for (var i = 0; i < queue.edits.length; i++)
            Row(
              children: [
                Expanded(child: Text(l10n.editText(queue.edits[i]))),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: l10n.editRemove,
                  onPressed: () =>
                      ref.read(editQueueProvider.notifier).removeAt(i),
                ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.read(editQueueProvider.notifier).clear(),
              child: Text(l10n.editClearQueue),
            ),
          ),
        ],
      ],
    );
  }
}

/// 適用前の見通し（SPEC FR-E5）。件数・変更前後・書き込み先タグを出す。
class _PreviewSection extends ConsumerWidget {
  const _PreviewSection();

  /// 変化を 1 件ずつ出す上限。残りは件数だけを示す。
  static const _shown = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final preview = ref.watch(editPreviewProvider);
    if (ref.watch(editQueueProvider).isEmpty) return const SizedBox.shrink();

    return _Section(
      title: l10n.editSectionPreview,
      children: [
        if (preview.isEmpty)
          Text(l10n.editPreviewNothing)
        else ...[
          for (final entry in preview.planned.take(_shown))
            _Change(entry: entry),
          if (preview.count > _shown)
            Text(
              l10n.editPreviewMore(preview.count - _shown),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Text(
            '${l10n.editPreviewTargetTags}: ${preview.targetTags.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (preview.unwritable.isNotEmpty)
          Text(
            l10n.editUnwritable(preview.unwritable.length),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

/// 1 件の変更前後。
class _Change extends StatelessWidget {
  const _Change({required this.entry});

  final PlannedEdit entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = entry.asset.summary;
    final plan = entry.plan;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            entry.asset.name,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
          if (plan.capturedChanged)
            _line(
              context,
              l10n.summaryFieldCapturedAt,
              // 秒までずらすことがあるので、見通しは秒を落とさずに出す。
              l10n.formatCapturedAt(summary?.capturedAt),
              l10n.formatCapturedAt(plan.capturedAt),
            ),
          if (plan.locationChanged)
            _line(
              context,
              l10n.summaryFieldLocation,
              summary?.location == null
                  ? l10n.valueAbsent
                  : formatCoordinates(summary!.location!),
              plan.location == null
                  ? l10n.valueAbsent
                  : formatCoordinates(plan.location!),
            ),
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    String before,
    String after,
  ) => Padding(
    padding: const EdgeInsets.only(left: 8, top: 2),
    child: Text(
      '$label: $before → $after',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

/// 適用と、その結果（SPEC FR-E5、FR-E6-4、FR-E7）。
class _ApplyBar extends ConsumerWidget {
  const _ApplyBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final apply = ref.watch(applyProvider);
    final preview = ref.watch(editPreviewProvider);

    if (apply.running) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.editApplying(apply.done, apply.total)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: apply.total == 0 ? null : apply.done / apply.total,
            ),
          ],
        ),
      );
    }

    if (apply.hasResult) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.editResultSucceeded(apply.succeeded)),
            if (apply.failures.isNotEmpty) ...[
              Text(
                l10n.editResultFailed(apply.failures.length),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              for (final reason in apply.failures.values.toSet())
                Text(
                  l10n.writeFailureLabel(reason),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (apply.canUndo)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(l10n.editUndo),
                    onPressed: () => ref.read(applyProvider.notifier).undo(),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref.read(applyProvider.notifier).dismiss(),
                  child: Text(l10n.actionClose),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 書けないプラットフォームでは、隠さず理由を添えて押せなくする（SPEC §8）。
    final canWrite = platformCapabilities.writeMetadata;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Tooltip(
        message: canWrite ? '' : l10n.capabilityUnavailable,
        child: FilledButton.icon(
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(
            preview.isEmpty
                ? l10n.editApply
                : l10n.editApplyCount(preview.count),
          ),
          onPressed: preview.isEmpty || !canWrite
              ? null
              : () => _confirmAndApply(context, ref, preview),
        ),
      ),
    );
  }

  /// 元のファイルを書き換える前に、件数を添えて確かめる（SPEC §10）。
  Future<void> _confirmAndApply(
    BuildContext context,
    WidgetRef ref,
    EditPreview preview,
  ) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(preview: preview),
    );
    if (agreed != true) return;
    await ref.read(applyProvider.notifier).apply(preview);
  }
}

/// 書き込みの確認（SPEC §10）。件数と書き込み先、控えの有無を出す。
class _ConfirmDialog extends ConsumerWidget {
  const _ConfirmDialog({required this.preview});

  final EditPreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final backup = ref.watch(settingsProvider).backupEnabled;

    return AlertDialog(
      title: Text(l10n.editConfirmTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.editConfirmBody(preview.count)),
            const SizedBox(height: 8),
            Text(
              '${l10n.editPreviewTargetTags}: ${preview.targetTags.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              backup ? l10n.editConfirmBackup : l10n.editConfirmNoBackup,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: backup ? null : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.editApply),
        ),
      ],
    );
  }
}
