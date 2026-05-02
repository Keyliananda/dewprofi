import 'package:dewprofi/features/govee/govee_h5075_gatt_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const protocol = GoveeH5075GattProtocol();

  test('builds allowlisted current and battery requests with xor checksum', () {
    expect(protocol.buildCurrentMeasurementRequest(), const [
      0xAA,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0xAB,
    ]);
    expect(protocol.buildBatteryRequest().first, 0xAA);
    expect(protocol.buildBatteryRequest()[1], 0x08);
    expect(protocol.buildBatteryRequest().last, 0xA2);
  });

  test(
    'builds progressive history requests including guarded long windows',
    () {
      expect(
        protocol.buildHistoryRequest(GoveeH5075HistoryProbeWindow.tenMinutes),
        const [
          0x33,
          0x01,
          0x00,
          0x0A,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x39,
        ],
      );
      expect(
        protocol.buildHistoryRequest(GoveeH5075HistoryProbeWindow.sevenDays),
        const [
          0x33,
          0x01,
          0x27,
          0x60,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x74,
        ],
      );
      expect(
        protocol.buildHistoryRequest(GoveeH5075HistoryProbeWindow.twentyDays),
        const [
          0x33,
          0x01,
          0x70,
          0x80,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0xC3,
        ],
      );
      expect(
        protocol.buildHistoryRequest(GoveeH5075HistoryProbeWindow.thirtyDays),
        const [
          0x33,
          0x01,
          0xA8,
          0xC0,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x5B,
        ],
      );
      expect(
        () => protocol.buildHistoryRequestForMinutes(
          startMinutesBack: 43201,
          endMinutesBack: 1,
        ),
        throwsArgumentError,
      );
    },
  );

  test('builds resume history request for 14996 to 1', () {
    expect(
      protocol.buildHistoryRequestForChunk(
        const GoveeH5075HistoryChunk(
          startMinutesBack: 14996,
          endMinutesBack: 1,
          timeout: Duration(minutes: 15),
          idleCompletionDelay: Duration(seconds: 12),
        ),
      ),
      const [
        0x33,
        0x01,
        0x3A,
        0x94,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x9D,
      ],
    );
  });

  test('long history windows carry bounded but larger timeouts', () {
    expect(GoveeH5075HistoryProbeWindow.oneDay.timeout.inSeconds, 45);
    expect(
      GoveeH5075HistoryProbeWindow.oneDay.idleCompletionDelay,
      const Duration(seconds: 8),
    );
    expect(
      GoveeH5075HistoryProbeWindow.sevenDays.timeout,
      const Duration(minutes: 4),
    );
    expect(
      GoveeH5075HistoryProbeWindow.sevenDays.idleCompletionDelay,
      const Duration(seconds: 10),
    );
    expect(
      GoveeH5075HistoryProbeWindow.twentyDays.timeout,
      const Duration(minutes: 15),
    );
    expect(
      GoveeH5075HistoryProbeWindow.twentyDays.idleCompletionDelay,
      const Duration(seconds: 12),
    );
    expect(
      GoveeH5075HistoryProbeWindow.twentyDays.requiresConfirmation,
      isTrue,
    );
    expect(
      GoveeH5075HistoryProbeWindow.thirtyDays.timeout,
      const Duration(minutes: 20),
    );
    expect(
      GoveeH5075HistoryProbeWindow.thirtyDays.idleCompletionDelay,
      const Duration(seconds: 15),
    );
    expect(
      GoveeH5075HistoryProbeWindow.thirtyDays.requiresConfirmation,
      isTrue,
    );
  });

  test('parses current measurement and battery response samples', () {
    final measurement = protocol.parseCurrentMeasurementResponse(const [
      0xAA,
      0x01,
      0x08,
      0x98,
      0x0B,
      0x86,
      0x53,
      0x00,
    ], observedAt: DateTime(2026, 5, 1, 18, 47));

    expect(measurement?.temperatureCelsius, 22.0);
    expect(measurement?.relativeHumidityPercent, 29.5);
    expect(measurement?.batteryPercent, 83);
    expect(protocol.parseBatteryResponse(const [0xAA, 0x08, 0x53]), 83);
  });

  test('parses H5075 history notifications into minute records', () {
    final startedAt = DateTime(2026, 5, 1, 18, 47);
    final records = protocol.parseHistoryNotification(const [
      0x00,
      0x03,
      0x03,
      0x5C,
      0x87,
      0x03,
      0x5C,
      0x88,
      0x03,
      0x5C,
      0x89,
      0xFF,
      0xFF,
      0xFF,
      0xFF,
      0xFF,
      0xFF,
      0xFF,
      0xFF,
      0xFF,
    ], downloadStartedAt: startedAt);

    expect(records, hasLength(3));
    expect(records.first.minutesBack, 3);
    expect(records.first.observedAt, DateTime(2026, 5, 1, 18, 44));
    expect(records.first.temperatureCelsius, 22.0);
    expect(records.first.relativeHumidityPercent, 29.5);
    expect(records.last.minutesBack, 1);
  });

  test('dedupes history records by minutes back', () {
    final startedAt = DateTime(2026, 5, 1, 18, 47);
    final records = GoveeH5075HistoryRecords.dedupeByMinutesBack([
      _historyRecord(14997, startedAt, temperatureCelsius: 19.4),
      _historyRecord(14997, startedAt, temperatureCelsius: 99.9),
      _historyRecord(28800, startedAt, temperatureCelsius: 18.1),
    ]);

    expect(records, hasLength(2));
    expect(records.first.minutesBack, 28800);
    expect(records.last.minutesBack, 14997);
    expect(records.last.temperatureCelsius, 19.4);
  });

  test(
    'diagnoses history range and recommends next chunk after partial range',
    () {
      final startedAt = DateTime(2026, 5, 1, 18, 47);
      final diagnostics = GoveeH5075HistoryRangeDiagnostics.fromRecords(
        chunk: GoveeH5075HistoryProbeWindow.twentyDays.toChunk(),
        records: [
          _historyRecord(28800, startedAt),
          _historyRecord(15958, startedAt),
          _historyRecord(14997, startedAt),
          _historyRecord(14997, startedAt, relativeHumidityPercent: 41),
        ],
      );

      expect(diagnostics.uniqueRecords, 3);
      expect(diagnostics.rangeLabel, '-28800m..-14997m');
      expect(diagnostics.oldestRecord?.minutesBack, 28800);
      expect(diagnostics.newestRecord?.minutesBack, 14997);
      expect(diagnostics.nextRecommendedChunk?.startMinutesBack, 14996);
      expect(diagnostics.nextRecommendedChunk?.endMinutesBack, 1);
      expect(diagnostics.nextRecommendedChunk?.rangeLabel, '14996 -> 1');
    },
  );

  test('debug text shows history count plus first and last records', () {
    final startedAt = DateTime(2026, 5, 1, 18, 47);
    final snapshot = GoveeH5075GattProbeSnapshot(
      status: GoveeH5075GattProbeStatus.completed,
      historyWindow: GoveeH5075HistoryProbeWindow.sevenDays,
      historyRecords: [
        for (var index = 30; index >= 1; index -= 1)
          GoveeH5075HistoryRecord(
            minutesBack: index,
            observedAt: startedAt.subtract(Duration(minutes: index)),
            temperatureCelsius: 20 + index / 10,
            relativeHumidityPercent: 40 + index / 10,
          ),
      ],
    );

    final debugText = snapshot.toDebugText();

    expect(debugText, contains('historyRecords: 30'));
    expect(debugText, contains('historyChunk: 10080 -> 1'));
    expect(debugText, contains('historyRange: -30m..-1m'));
    expect(debugText, contains('historyOldest: -30m'));
    expect(debugText, contains('historyNewest: -1m'));
    expect(debugText, contains('-30m'));
    expect(debugText, contains('last -1m'));
  });

  test('debug text reports omitted raw history notifications compactly', () {
    final snapshot = GoveeH5075GattProbeSnapshot(
      status: GoveeH5075GattProbeStatus.requestingHistory,
      rawHistoryNotificationsOmitted: 4800,
      rawEvents: [
        GoveeH5075GattRawEvent(
          timestamp: DateTime(2026, 5, 1, 19, 28),
          direction: '<-- notify',
          characteristicUuid: goveeH5075HistoryCharacteristicUuid,
          bytes: const [0x57, 0x60, 0x02, 0x1D, 0xE1],
        ),
      ],
    );

    final debugText = snapshot.toDebugText();

    expect(debugText, contains('57 60 02 1D E1'));
    expect(debugText, contains('rawHistoryNotificationsOmitted: 4800'));
  });
}

GoveeH5075HistoryRecord _historyRecord(
  int minutesBack,
  DateTime startedAt, {
  double temperatureCelsius = 20,
  double relativeHumidityPercent = 40,
}) {
  return GoveeH5075HistoryRecord(
    minutesBack: minutesBack,
    observedAt: startedAt.subtract(Duration(minutes: minutesBack)),
    temperatureCelsius: temperatureCelsius,
    relativeHumidityPercent: relativeHumidityPercent,
  );
}
