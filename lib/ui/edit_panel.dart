import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/coordinates.dart';
import '../domain/edit.dart';
import '../domain/models.dart';
import '../domain/normalize.dart';
import '../l10n/l10n.dart';
import '../state/edits.dart';
import '../state/search.dart';
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
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _altitude = TextEditingController();

  TimeZoneMode _zoneMode = TimeZoneMode.reinterpret;

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
      _latitude,
      _longitude,
      _altitude,
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
                children: [_shiftRow(), _setTimeRow(), _timeZoneRow()],
              ),
              _Section(
                title: l10n.editSectionLocation,
                children: [_locationRows()],
              ),
              _Section(
                title: l10n.editSectionTargets,
                children: [_targetsRow()],
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
            _amount(_days, l10n.editUnitDays),
            _amount(_hours, l10n.editUnitHours),
            _amount(_minutes, l10n.editUnitMinutes),
            _amount(_seconds, l10n.editUnitSeconds),
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

  Widget _amount(TextEditingController controller, String unit) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextField(
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
            _AddButton(onPressed: _queueSetTime),
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
            _AddButton(onPressed: _queueTimeZone),
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
            _AddButton(onPressed: _queueLocation),
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

  Widget _coordinate(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      );

  /// 主対象の位置。選択集合へ配るための種になる（SPEC FR-E4-3）。
  GeoPoint? _primaryLocation() {
    final primary = ref.watch(selectionProvider).primary;
    if (primary == null) return null;
    for (final asset in ref.watch(displayedAssetsProvider)) {
      if (asset.path == primary) return asset.summary?.location;
    }
    return null;
  }

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

  /// 時刻の書き込み先（SPEC FR-E3-7）。
  Widget _targetsRow() {
    final l10n = context.l10n;
    final targets = ref.watch(editQueueProvider).timeTargets;
    return Wrap(
      spacing: 8,
      children: [
        for (final target in TimeTarget.values)
          FilterChip(
            label: Text(l10n.timeTargetLabel(target)),
            selected: targets.contains(target),
            onSelected: (selected) {
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
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

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

    return Padding(
      padding: const EdgeInsets.all(12),
      child: FilledButton.icon(
        icon: const Icon(Icons.save_outlined, size: 18),
        label: Text(
          preview.isEmpty ? l10n.editApply : l10n.editApplyCount(preview.count),
        ),
        onPressed: preview.isEmpty
            ? null
            : () => ref.read(applyProvider.notifier).apply(preview),
      ),
    );
  }
}
