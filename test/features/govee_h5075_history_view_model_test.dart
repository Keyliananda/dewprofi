import 'package:dewprofi/core/sensors/ble_advertisement.dart';
import 'package:dewprofi/features/govee/govee_h5075_gatt_probe.dart';
import 'package:dewprofi/features/govee/govee_h5075_history_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dedupes history records by observed minute and sorts chronologically',
    () {
      final anchor = DateTime(2026, 5, 2, 7, 24);
      final records = dedupeHistoryRecordsByObservedMinute([
        _record(anchor.subtract(const Duration(minutes: 1)), 12),
        _record(anchor.subtract(const Duration(minutes: 3)), 10),
        _record(anchor.subtract(const Duration(minutes: 1, seconds: 20)), 99),
        _record(anchor.subtract(const Duration(minutes: 2)), 11),
      ]);

      expect(records, hasLength(3));
      expect(records.first.temperatureCelsius, 10);
      expect(records.last.temperatureCelsius, 12);
    },
  );

  test('builds period stats and coverage from visible raw records', () {
    final anchor = DateTime(2026, 5, 2, 7, 24);
    final snapshot = GoveeH5075GattProbeSnapshot(
      status: GoveeH5075GattProbeStatus.completed,
      device: _advertisement(),
      batteryPercent: 95,
      historyRecords: [
        _record(anchor.subtract(const Duration(minutes: 60)), 10),
        _record(anchor.subtract(const Duration(minutes: 30)), 20),
        _record(anchor.subtract(const Duration(minutes: 1)), 30),
        _record(anchor.subtract(const Duration(hours: 2)), 99),
      ],
    );

    final model = GoveeH5075HistoryViewModel.fromSnapshot(
      snapshot,
      period: GoveeH5075HistoryDisplayPeriod.hour,
      anchor: anchor,
    );

    expect(model.deviceName, 'GVH5075_47EE');
    expect(model.batteryPercent, 95);
    expect(model.temperatureChart.minimum, 10);
    expect(model.temperatureChart.average, 20);
    expect(model.temperatureChart.maximum, 30);
    expect(model.temperatureChart.points, hasLength(3));
    expect(model.coverage.expectedMinutes, 61);
    expect(model.coverage.uniqueRecords, 3);
    expect(model.coverage.missingRecords, 58);
  });

  test('preserves bucket extremes and marks larger gaps', () {
    final anchor = DateTime(2026, 5, 2, 7, 24);
    final rangeStart = anchor.subtract(const Duration(days: 30));
    final chart = GoveeH5075HistoryMetricChart.fromRecords(
      title: 'Temperatur',
      unit: 'C',
      rangeStart: rangeStart,
      rangeEnd: anchor,
      bucketSize: const Duration(hours: 2),
      valueFor: (record) => record.temperatureCelsius,
      records: [
        _record(rangeStart.add(const Duration(minutes: 10)), 12),
        _record(rangeStart.add(const Duration(minutes: 50)), 28),
        _record(rangeStart.add(const Duration(days: 5)), 16),
      ],
    );

    expect(chart.points.map((point) => point.value), containsAll([12, 28, 16]));
    expect(chart.points.any((point) => point.hasGapAfter), isTrue);
  });
}

BleAdvertisement _advertisement() {
  return BleAdvertisement(
    deviceId: 'AA:BB:CC:DD:EE:47',
    deviceName: 'GVH5075_47EE',
    observedAt: DateTime(2026, 5, 2, 7, 24),
  );
}

GoveeH5075HistoryRecord _record(DateTime observedAt, double temperature) {
  return GoveeH5075HistoryRecord(
    minutesBack: 0,
    observedAt: observedAt,
    temperatureCelsius: temperature,
    relativeHumidityPercent: 40 + temperature / 10,
  );
}
