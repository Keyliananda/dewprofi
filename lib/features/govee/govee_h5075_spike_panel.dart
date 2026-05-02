import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sensors/ble_advertisement.dart';
import '../../core/sensors/sensor_measurement.dart';
import '../sensors/ble_advertisement_scanner.dart';
import 'govee_h5075_gatt_probe.dart';
import 'govee_h5075_history_overview.dart';
import 'govee_h5075_parser.dart';

class GoveeH5075SpikePanel extends StatelessWidget {
  const GoveeH5075SpikePanel({
    super.key,
    required this.snapshot,
    required this.visibleAdvertisements,
    required this.minimumRssi,
    required this.discoveries,
    required this.gattProbeSnapshot,
    required this.historyProbeWindow,
    required this.onStartScan,
    required this.onStopScan,
    required this.onMinimumRssiChanged,
    required this.onApplyMeasurement,
    required this.onStartGattProbe,
    required this.onStartHistoryChunk,
    required this.onAbortGattProbe,
    required this.onHistoryProbeWindowChanged,
  });

  final BleScanSnapshot snapshot;
  final List<BleAdvertisement> visibleAdvertisements;
  final int minimumRssi;
  final List<GoveeH5075Discovery> discoveries;
  final GoveeH5075GattProbeSnapshot gattProbeSnapshot;
  final GoveeH5075HistoryProbeWindow historyProbeWindow;
  final VoidCallback onStartScan;
  final VoidCallback onStopScan;
  final ValueChanged<int> onMinimumRssiChanged;
  final ValueChanged<LiveSensorMeasurement> onApplyMeasurement;
  final ValueChanged<BleAdvertisement> onStartGattProbe;
  final ValueChanged<GoveeH5075HistoryChunk> onStartHistoryChunk;
  final VoidCallback onAbortGattProbe;
  final ValueChanged<GoveeH5075HistoryProbeWindow> onHistoryProbeWindowChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isScanning = snapshot.isScanning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Govee H5075 Spike',
                style: theme.textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              key: const ValueKey('govee-scan-toggle-button'),
              onPressed: isScanning ? onStopScan : onStartScan,
              icon: Icon(isScanning ? Icons.stop : Icons.sensors),
              label: Text(isScanning ? 'Stoppen' : 'Scannen'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StatusLine(
          snapshot: snapshot,
          visibleCount: visibleAdvertisements.length,
          minimumRssi: minimumRssi,
        ),
        const SizedBox(height: 12),
        _MinimumRssiControl(
          value: minimumRssi,
          onChanged: onMinimumRssiChanged,
        ),
        const SizedBox(height: 12),
        if (discoveries.isEmpty)
          Text(
            visibleAdvertisements.isNotEmpty
                ? 'Noch kein H5075-Kandidat.'
                : snapshot.advertisements.isEmpty
                ? 'Noch keine BLE-Advertisements.'
                : 'Keine Advertisements ueber Mindestsignal.',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final discovery in discoveries.take(4)) ...[
            _DiscoveryTile(
              discovery: discovery,
              onApplyMeasurement: onApplyMeasurement,
              onStartGattProbe: onStartGattProbe,
              probeRunning: gattProbeSnapshot.isRunning,
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 4),
        _GattProbePanel(
          snapshot: gattProbeSnapshot,
          historyProbeWindow: historyProbeWindow,
          hasCandidate: discoveries.isNotEmpty,
          onAbort: onAbortGattProbe,
          onStartHistoryChunk: onStartHistoryChunk,
          onHistoryProbeWindowChanged: onHistoryProbeWindowChanged,
        ),
        if (visibleAdvertisements.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Raw Samples', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final advertisement in visibleAdvertisements.take(3)) ...[
            _RawAdvertisementTile(advertisement: advertisement),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.snapshot,
    required this.visibleCount,
    required this.minimumRssi,
  });

  final BleScanSnapshot snapshot;
  final int visibleCount;
  final int minimumRssi;

  @override
  Widget build(BuildContext context) {
    final message = snapshot.message ?? _statusLabel(snapshot.status);
    return Row(
      children: [
        Icon(
          snapshot.isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$message · $visibleCount/${snapshot.advertisements.length} Advertisements ab $minimumRssi dBm',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(BleScannerStatus status) {
    return switch (status) {
      BleScannerStatus.idle => 'Bereit',
      BleScannerStatus.scanning => 'Scan laeuft',
      BleScannerStatus.unsupported => 'Nicht unterstuetzt',
      BleScannerStatus.unauthorized => 'Keine Berechtigung',
      BleScannerStatus.poweredOff => 'Bluetooth aus',
      BleScannerStatus.error => 'Fehler',
    };
  }
}

class _MinimumRssiControl extends StatelessWidget {
  const _MinimumRssiControl({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.signal_cellular_alt, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Mindestsignal', style: theme.textTheme.labelLarge),
            ),
            Text(
              '$value dBm',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          key: const ValueKey('govee-minimum-rssi-slider'),
          min: -100,
          max: -40,
          divisions: 12,
          value: value.toDouble(),
          label: '$value dBm',
          onChanged: (nextValue) => onChanged(nextValue.round()),
        ),
      ],
    );
  }
}

class _DiscoveryTile extends StatelessWidget {
  const _DiscoveryTile({
    required this.discovery,
    required this.onApplyMeasurement,
    required this.onStartGattProbe,
    required this.probeRunning,
  });

  final GoveeH5075Discovery discovery;
  final ValueChanged<LiveSensorMeasurement> onApplyMeasurement;
  final ValueChanged<BleAdvertisement> onStartGattProbe;
  final bool probeRunning;

  @override
  Widget build(BuildContext context) {
    final measurement = discovery.measurement;
    final advertisement = discovery.advertisement;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.device_thermostat, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    advertisement.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (advertisement.rssi != null)
                  Text(
                    '${advertisement.rssi} dBm',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(discovery.reason, style: theme.textTheme.bodySmall),
            if (measurement != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _MiniMetric(
                    label: 'Temp',
                    value:
                        '${_formatNumber(measurement.temperatureCelsius)} °C',
                  ),
                  _MiniMetric(
                    label: 'rF',
                    value:
                        '${_formatNumber(measurement.relativeHumidityPercent)} %',
                  ),
                  if (measurement.batteryPercent != null)
                    _MiniMetric(
                      label: 'Akku',
                      value: '${measurement.batteryPercent} %',
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('apply-govee-measurement-button'),
                      onPressed: () => onApplyMeasurement(measurement),
                      icon: const Icon(Icons.arrow_circle_right),
                      label: const Text('Wert uebernehmen'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('start-govee-gatt-probe-button'),
                      onPressed: probeRunning
                          ? null
                          : () => onStartGattProbe(advertisement),
                      icon: const Icon(Icons.history),
                      label: const Text('GATT-Probe'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('start-govee-gatt-probe-button'),
                  onPressed: probeRunning
                      ? null
                      : () => onStartGattProbe(advertisement),
                  icon: const Icon(Icons.history),
                  label: const Text('GATT-Probe'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GattProbePanel extends StatelessWidget {
  const _GattProbePanel({
    required this.snapshot,
    required this.historyProbeWindow,
    required this.hasCandidate,
    required this.onAbort,
    required this.onStartHistoryChunk,
    required this.onHistoryProbeWindowChanged,
  });

  final GoveeH5075GattProbeSnapshot snapshot;
  final GoveeH5075HistoryProbeWindow historyProbeWindow;
  final bool hasCandidate;
  final VoidCallback onAbort;
  final ValueChanged<GoveeH5075HistoryChunk> onStartHistoryChunk;
  final ValueChanged<GoveeH5075HistoryProbeWindow> onHistoryProbeWindowChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRunning = snapshot.isRunning;
    final historyChunk = snapshot.effectiveHistoryChunk;
    final historyDiagnostics = snapshot.historyDiagnostics;
    final nextHistoryChunk = historyDiagnostics?.nextRecommendedChunk;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history_toggle_off, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'History-Probe',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (isRunning)
                  IconButton(
                    tooltip: 'GATT-Probe abbrechen',
                    onPressed: onAbort,
                    icon: const Icon(Icons.stop_circle),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<GoveeH5075HistoryProbeWindow>(
                segments: const [
                  ButtonSegment(
                    value: GoveeH5075HistoryProbeWindow.tenMinutes,
                    label: Text('10 min'),
                  ),
                  ButtonSegment(
                    value: GoveeH5075HistoryProbeWindow.oneHour,
                    label: Text('1 h'),
                  ),
                  ButtonSegment(
                    value: GoveeH5075HistoryProbeWindow.oneDay,
                    label: Text('24 h'),
                  ),
                  ButtonSegment(
                    value: GoveeH5075HistoryProbeWindow.sevenDays,
                    label: Text('7 d'),
                  ),
                  ButtonSegment(
                    value: GoveeH5075HistoryProbeWindow.twentyDays,
                    label: Text('20 d'),
                  ),
                  ButtonSegment(
                    value: GoveeH5075HistoryProbeWindow.thirtyDays,
                    label: Text('30 d'),
                  ),
                ],
                selected: {historyProbeWindow},
                onSelectionChanged: isRunning
                    ? null
                    : (selection) =>
                          _selectHistoryWindow(context, selection.single),
              ),
            ),
            const SizedBox(height: 8),
            if (historyProbeWindow == GoveeH5075HistoryProbeWindow.sevenDays)
              _ProbeNotice(
                icon: Icons.schedule,
                text:
                    '7 Tage fragt 10080 Minuten an. Erst nach stabilem 24-h-Log verwenden; Abbruch bleibt moeglich.',
              ),
            if (historyProbeWindow == GoveeH5075HistoryProbeWindow.twentyDays)
              const _ProbeNotice(
                icon: Icons.warning_amber,
                text:
                    'Experimenteller 20-Tage-Abruf: 28800 Minuten, kann lange dauern, abbrechen oder die Verbindung verlieren.',
              ),
            if (historyProbeWindow == GoveeH5075HistoryProbeWindow.thirtyDays)
              const _ProbeNotice(
                icon: Icons.warning_amber,
                text:
                    'Experimenteller 30-Tage-Abruf: 43200 Minuten, unbestaetigt fuer H5075 und nur fuer diesen Hardwaretest.',
              ),
            if (historyProbeWindow == GoveeH5075HistoryProbeWindow.sevenDays ||
                historyProbeWindow == GoveeH5075HistoryProbeWindow.twentyDays ||
                historyProbeWindow == GoveeH5075HistoryProbeWindow.thirtyDays)
              const SizedBox(height: 8),
            _GattStatusLine(snapshot: snapshot, hasCandidate: hasCandidate),
            if (snapshot.currentMeasurement != null ||
                snapshot.batteryPercent != null ||
                historyChunk != null ||
                snapshot.historyRecords.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (historyChunk != null)
                    _MiniMetric(
                      label: 'Chunk',
                      value: historyChunk.rangeLabel,
                      width: 118,
                    ),
                  if (historyDiagnostics != null)
                    _MiniMetric(
                      label: 'Unique',
                      value: '${historyDiagnostics.uniqueRecords}',
                    ),
                  if (historyDiagnostics?.hasRecords ?? false)
                    _MiniMetric(
                      label: 'Range',
                      value: historyDiagnostics!.rangeLabel,
                      width: 132,
                    ),
                  if (snapshot.currentMeasurement != null)
                    _MiniMetric(
                      label: 'GATT Temp',
                      value:
                          '${_formatNumber(snapshot.currentMeasurement!.temperatureCelsius)} °C',
                    ),
                  if (snapshot.currentMeasurement != null)
                    _MiniMetric(
                      label: 'GATT rF',
                      value:
                          '${_formatNumber(snapshot.currentMeasurement!.relativeHumidityPercent)} %',
                    ),
                  if (snapshot.batteryPercent != null)
                    _MiniMetric(
                      label: 'GATT Akku',
                      value: '${snapshot.batteryPercent} %',
                    ),
                  if (snapshot.historyRecords.isNotEmpty)
                    _MiniMetric(
                      label: 'History',
                      value: '${snapshot.historyRecords.length}',
                    ),
                ],
              ),
            ],
            if (nextHistoryChunk != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ProbeNotice(
                      icon: Icons.playlist_add_check,
                      text: 'Naechster Chunk ${nextHistoryChunk.rangeLabel}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'start-govee-next-history-chunk-button',
                    ),
                    onPressed: isRunning || snapshot.device == null
                        ? null
                        : () => onStartHistoryChunk(nextHistoryChunk),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Folgechunk'),
                  ),
                ],
              ),
            ],
            if (snapshot.historyRecords.isNotEmpty) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey('open-govee-history-overview-button'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GoveeH5075HistoryOverviewPage(snapshot: snapshot),
                  ),
                ),
                icon: const Icon(Icons.insert_chart_outlined),
                label: const Text('Historie'),
              ),
            ],
            if (snapshot.rawEvents.isNotEmpty ||
                snapshot.services.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Raw GATT Log',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Raw GATT Log kopieren',
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: snapshot.toDebugText()),
                    ),
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              SelectableText(
                snapshot.toDebugText(),
                maxLines: 12,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectHistoryWindow(
    BuildContext context,
    GoveeH5075HistoryProbeWindow window,
  ) async {
    if (!window.requiresConfirmation) {
      onHistoryProbeWindowChanged(window);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${window.label.replaceAll(' d', '')}-Tage-Probe aktivieren?',
        ),
        content: Text(
          'Dieser experimentelle Abruf fragt ${window.startMinutesBack} Minuten H5075-History an. Er kann bis zum Timeout laufen, abbrechen oder die Govee-App kurz blockieren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('${window.label.replaceAll(' d', '')} Tage aktivieren'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      onHistoryProbeWindowChanged(window);
    }
  }
}

class _ProbeNotice extends StatelessWidget {
  const _ProbeNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _GattStatusLine extends StatelessWidget {
  const _GattStatusLine({required this.snapshot, required this.hasCandidate});

  final GoveeH5075GattProbeSnapshot snapshot;
  final bool hasCandidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = snapshot.message ?? _fallbackMessage();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          snapshot.isRunning ? Icons.bluetooth_connected : Icons.bluetooth,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _fallbackMessage() {
    if (!hasCandidate) {
      return 'Erst H5075-Kandidat scannen, dann GATT-Probe manuell starten.';
    }
    return 'Manueller Probe-Flow: Service Discovery, aktuelle Werte, Batterie, kurzes History-Fenster.';
  }
}

class _RawAdvertisementTile extends StatelessWidget {
  const _RawAdvertisementTile({required this.advertisement});

  final BleAdvertisement advertisement;

  @override
  Widget build(BuildContext context) {
    final debugText = advertisement.toDebugText();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    advertisement.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Raw Sample kopieren',
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: debugText)),
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            SelectableText(
              debugText,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    this.width = 86,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

String _formatNumber(double value) {
  return value.toStringAsFixed(1).replaceAll('.', ',');
}
