import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sensors/ble_advertisement.dart';
import '../../core/sensors/sensor_measurement.dart';
import '../sensors/ble_advertisement_scanner.dart';
import 'govee_h5075_parser.dart';

class GoveeH5075SpikePanel extends StatelessWidget {
  const GoveeH5075SpikePanel({
    super.key,
    required this.snapshot,
    required this.visibleAdvertisements,
    required this.minimumRssi,
    required this.discoveries,
    required this.onStartScan,
    required this.onStopScan,
    required this.onMinimumRssiChanged,
    required this.onApplyMeasurement,
  });

  final BleScanSnapshot snapshot;
  final List<BleAdvertisement> visibleAdvertisements;
  final int minimumRssi;
  final List<GoveeH5075Discovery> discoveries;
  final VoidCallback onStartScan;
  final VoidCallback onStopScan;
  final ValueChanged<int> onMinimumRssiChanged;
  final ValueChanged<LiveSensorMeasurement> onApplyMeasurement;

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
            ),
            const SizedBox(height: 10),
          ],
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
  });

  final GoveeH5075Discovery discovery;
  final ValueChanged<LiveSensorMeasurement> onApplyMeasurement;

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
                child: OutlinedButton.icon(
                  key: const ValueKey('apply-govee-measurement-button'),
                  onPressed: () => onApplyMeasurement(measurement),
                  icon: const Icon(Icons.arrow_circle_right),
                  label: const Text('Wert uebernehmen'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
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
