import 'dart:math' as math;

import 'govee_h5075_gatt_probe.dart';

enum GoveeH5075HistoryDisplayPeriod {
  hour('Stunde', Duration(hours: 1), Duration(minutes: 1)),
  day('Tag', Duration(days: 1), Duration(minutes: 5)),
  week('Woche', Duration(days: 7), Duration(hours: 1)),
  month('Monat', Duration(days: 30), Duration(hours: 2)),
  year('Jahr', Duration(days: 365), Duration(days: 1));

  const GoveeH5075HistoryDisplayPeriod(
    this.label,
    this.duration,
    this.bucketSize,
  );

  final String label;
  final Duration duration;
  final Duration bucketSize;
}

class GoveeH5075HistoryViewModel {
  GoveeH5075HistoryViewModel({
    required this.deviceName,
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.temperatureChart,
    required this.humidityChart,
    required this.coverage,
    required this.latestRecord,
    this.currentMeasurement,
    this.batteryPercent,
  });

  factory GoveeH5075HistoryViewModel.fromSnapshot(
    GoveeH5075GattProbeSnapshot snapshot, {
    GoveeH5075HistoryDisplayPeriod period =
        GoveeH5075HistoryDisplayPeriod.month,
    DateTime? anchor,
  }) {
    final records = dedupeHistoryRecordsByObservedMinute(
      snapshot.historyRecords,
    );
    final latestRecord = records.isEmpty ? null : records.last;
    final currentMeasurement = snapshot.currentMeasurement;
    final rangeEnd =
        anchor ??
        currentMeasurement?.observedAt ??
        latestRecord?.observedAt ??
        DateTime.now();
    final rangeStart = rangeEnd.subtract(period.duration);
    final visibleRecords = records
        .where(
          (record) =>
              !record.observedAt.isBefore(rangeStart) &&
              !record.observedAt.isAfter(rangeEnd),
        )
        .toList();

    return GoveeH5075HistoryViewModel(
      deviceName: snapshot.device?.displayName ?? 'H5075',
      period: period,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      temperatureChart: GoveeH5075HistoryMetricChart.fromRecords(
        title: 'Temperatur',
        unit: 'C',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        records: visibleRecords,
        bucketSize: period.bucketSize,
        valueFor: (record) => record.temperatureCelsius,
      ),
      humidityChart: GoveeH5075HistoryMetricChart.fromRecords(
        title: 'Relative Luftfeuchtigkeit',
        unit: '%',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        records: visibleRecords,
        bucketSize: period.bucketSize,
        valueFor: (record) => record.relativeHumidityPercent,
      ),
      coverage: GoveeH5075HistoryCoverage.fromRecords(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        records: visibleRecords,
      ),
      latestRecord: latestRecord,
      currentMeasurement: currentMeasurement,
      batteryPercent: snapshot.batteryPercent,
    );
  }

  final String deviceName;
  final GoveeH5075HistoryDisplayPeriod period;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final GoveeH5075HistoryMetricChart temperatureChart;
  final GoveeH5075HistoryMetricChart humidityChart;
  final GoveeH5075HistoryCoverage coverage;
  final GoveeH5075HistoryRecord? latestRecord;
  final GoveeH5075GattMeasurement? currentMeasurement;
  final int? batteryPercent;

  double? get currentTemperatureCelsius =>
      currentMeasurement?.temperatureCelsius ??
      latestRecord?.temperatureCelsius;

  double? get currentRelativeHumidityPercent =>
      currentMeasurement?.relativeHumidityPercent ??
      latestRecord?.relativeHumidityPercent;

  DateTime? get lastUpdatedAt =>
      currentMeasurement?.observedAt ?? latestRecord?.observedAt;

  bool get hasVisibleHistory =>
      temperatureChart.points.isNotEmpty || humidityChart.points.isNotEmpty;
}

class GoveeH5075HistoryMetricChart {
  GoveeH5075HistoryMetricChart({
    required this.title,
    required this.unit,
    required this.rangeStart,
    required this.rangeEnd,
    required this.points,
    required this.minimum,
    required this.average,
    required this.maximum,
  });

  factory GoveeH5075HistoryMetricChart.fromRecords({
    required String title,
    required String unit,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<GoveeH5075HistoryRecord> records,
    required Duration bucketSize,
    required double Function(GoveeH5075HistoryRecord record) valueFor,
  }) {
    if (records.isEmpty) {
      return GoveeH5075HistoryMetricChart(
        title: title,
        unit: unit,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        points: const [],
        minimum: null,
        average: null,
        maximum: null,
      );
    }

    final values = records.map(valueFor).toList();
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final average = values.reduce((a, b) => a + b) / values.length;
    final points = _bucketedPoints(
      records: records,
      rangeStart: rangeStart,
      bucketSize: bucketSize,
      valueFor: valueFor,
    );

    return GoveeH5075HistoryMetricChart(
      title: title,
      unit: unit,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      points: _markGaps(points, bucketSize),
      minimum: minimum,
      average: average,
      maximum: maximum,
    );
  }

  final String title;
  final String unit;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<GoveeH5075HistoryChartPoint> points;
  final double? minimum;
  final double? average;
  final double? maximum;

  double get displayMinimum {
    final minValue = minimum;
    final maxValue = maximum;
    if (minValue == null || maxValue == null) {
      return 0;
    }
    if ((maxValue - minValue).abs() < 0.1) {
      return minValue - 1;
    }
    return minValue - (maxValue - minValue) * 0.12;
  }

  double get displayMaximum {
    final minValue = minimum;
    final maxValue = maximum;
    if (minValue == null || maxValue == null) {
      return 1;
    }
    if ((maxValue - minValue).abs() < 0.1) {
      return maxValue + 1;
    }
    return maxValue + (maxValue - minValue) * 0.12;
  }
}

class GoveeH5075HistoryChartPoint {
  const GoveeH5075HistoryChartPoint({
    required this.observedAt,
    required this.value,
    this.hasGapAfter = false,
  });

  final DateTime observedAt;
  final double value;
  final bool hasGapAfter;

  GoveeH5075HistoryChartPoint copyWith({bool? hasGapAfter}) {
    return GoveeH5075HistoryChartPoint(
      observedAt: observedAt,
      value: value,
      hasGapAfter: hasGapAfter ?? this.hasGapAfter,
    );
  }
}

class GoveeH5075HistoryCoverage {
  const GoveeH5075HistoryCoverage({
    required this.expectedMinutes,
    required this.uniqueRecords,
    required this.missingRecords,
    required this.coveragePercent,
    required this.largestGap,
  });

  factory GoveeH5075HistoryCoverage.fromRecords({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<GoveeH5075HistoryRecord> records,
  }) {
    final expectedMinutes = math.max(
      1,
      rangeEnd.difference(rangeStart).inMinutes + 1,
    );
    var largestGap = Duration.zero;
    for (var index = 1; index < records.length; index += 1) {
      final gap = records[index].observedAt.difference(
        records[index - 1].observedAt,
      );
      if (gap > largestGap) {
        largestGap = gap;
      }
    }
    final uniqueRecords = records.length;
    return GoveeH5075HistoryCoverage(
      expectedMinutes: expectedMinutes,
      uniqueRecords: uniqueRecords,
      missingRecords: math.max(0, expectedMinutes - uniqueRecords),
      coveragePercent: uniqueRecords / expectedMinutes * 100,
      largestGap: largestGap,
    );
  }

  final int expectedMinutes;
  final int uniqueRecords;
  final int missingRecords;
  final double coveragePercent;
  final Duration largestGap;
}

List<GoveeH5075HistoryRecord> dedupeHistoryRecordsByObservedMinute(
  Iterable<GoveeH5075HistoryRecord> records,
) {
  final recordsByMinute = <int, GoveeH5075HistoryRecord>{};
  for (final record in records) {
    recordsByMinute.putIfAbsent(
      record.observedAt.millisecondsSinceEpoch ~/
          Duration.millisecondsPerMinute,
      () => record,
    );
  }
  return recordsByMinute.values.toList()
    ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
}

List<GoveeH5075HistoryChartPoint> _bucketedPoints({
  required List<GoveeH5075HistoryRecord> records,
  required DateTime rangeStart,
  required Duration bucketSize,
  required double Function(GoveeH5075HistoryRecord record) valueFor,
}) {
  final bucketMillis = math.max(
    Duration.millisecondsPerMinute,
    bucketSize.inMilliseconds,
  );
  final buckets = <int, List<GoveeH5075HistoryRecord>>{};
  for (final record in records) {
    final bucketIndex =
        record.observedAt.difference(rangeStart).inMilliseconds ~/ bucketMillis;
    buckets.putIfAbsent(bucketIndex, () => []).add(record);
  }

  final points = <GoveeH5075HistoryChartPoint>[];
  final sortedBuckets = buckets.keys.toList()..sort();
  for (final bucketIndex in sortedBuckets) {
    final bucketRecords = buckets[bucketIndex]!
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
    if (bucketRecords.length == 1) {
      final record = bucketRecords.single;
      points.add(
        GoveeH5075HistoryChartPoint(
          observedAt: record.observedAt,
          value: valueFor(record),
        ),
      );
      continue;
    }

    var minRecord = bucketRecords.first;
    var maxRecord = bucketRecords.first;
    for (final record in bucketRecords.skip(1)) {
      if (valueFor(record) < valueFor(minRecord)) {
        minRecord = record;
      }
      if (valueFor(record) > valueFor(maxRecord)) {
        maxRecord = record;
      }
    }

    final orderedExtremeRecords = [minRecord, maxRecord]
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
    for (final record in orderedExtremeRecords) {
      if (points.isNotEmpty &&
          points.last.observedAt == record.observedAt &&
          (points.last.value - valueFor(record)).abs() < 0.001) {
        continue;
      }
      points.add(
        GoveeH5075HistoryChartPoint(
          observedAt: record.observedAt,
          value: valueFor(record),
        ),
      );
    }
  }
  return points;
}

List<GoveeH5075HistoryChartPoint> _markGaps(
  List<GoveeH5075HistoryChartPoint> points,
  Duration bucketSize,
) {
  if (points.length < 2) {
    return points;
  }
  final gapThreshold = Duration(
    milliseconds: math.max(
      Duration(minutes: 3).inMilliseconds,
      (bucketSize.inMilliseconds * 2.5).round(),
    ),
  );
  final nextPoints = <GoveeH5075HistoryChartPoint>[];
  for (var index = 0; index < points.length; index += 1) {
    final point = points[index];
    final hasGapAfter =
        index < points.length - 1 &&
        points[index + 1].observedAt.difference(point.observedAt) >
            gapThreshold;
    nextPoints.add(point.copyWith(hasGapAfter: hasGapAfter));
  }
  return nextPoints;
}
