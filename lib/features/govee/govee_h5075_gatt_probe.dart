import '../../core/sensors/ble_advertisement.dart';

const String goveeH5075GattServiceUuid = '494e5445-4c4c-495f-524f-434b535f4857';
const String goveeH5075DeviceCharacteristicUuid =
    '494e5445-4c4c-495f-524f-434b535f2011';
const String goveeH5075CommandCharacteristicUuid =
    '494e5445-4c4c-495f-524f-434b535f2012';
const String goveeH5075HistoryCharacteristicUuid =
    '494e5445-4c4c-495f-524f-434b535f2013';
const int goveeH5075MaxHistoryMinutesBack = 43200;
const int goveeH5075MinHistoryEndMinutesBack = 1;

enum GoveeH5075GattProbeStatus {
  idle,
  connecting,
  discoveringServices,
  enablingNotifications,
  readingCurrent,
  readingBattery,
  requestingHistory,
  completed,
  aborted,
  unsupported,
  error,
}

enum GoveeH5075HistoryProbeWindow {
  tenMinutes(10, '10 min', Duration(seconds: 12), Duration(seconds: 4)),
  oneHour(60, '1 h', Duration(seconds: 20), Duration(seconds: 5)),
  oneDay(1440, '24 h', Duration(seconds: 45), Duration(seconds: 8)),
  sevenDays(10080, '7 d', Duration(minutes: 4), Duration(seconds: 10)),
  twentyDays(
    28800,
    '20 d',
    Duration(minutes: 15),
    Duration(seconds: 12),
    requiresConfirmation: true,
  ),
  thirtyDays(
    43200,
    '30 d',
    Duration(minutes: 20),
    Duration(seconds: 15),
    requiresConfirmation: true,
  );

  const GoveeH5075HistoryProbeWindow(
    this.startMinutesBack,
    this.label,
    this.timeout,
    this.idleCompletionDelay, {
    this.requiresConfirmation = false,
  });

  final int startMinutesBack;
  final String label;
  final Duration timeout;
  final Duration idleCompletionDelay;
  final bool requiresConfirmation;

  int get endMinutesBack => 1;

  String get timeoutLabel {
    final minutes = timeout.inMinutes;
    if (minutes >= 1 && timeout.inSeconds % 60 == 0) {
      return '$minutes min';
    }
    return '${timeout.inSeconds} s';
  }

  GoveeH5075HistoryChunk toChunk() {
    return GoveeH5075HistoryChunk(
      startMinutesBack: startMinutesBack,
      endMinutesBack: endMinutesBack,
      timeout: timeout,
      idleCompletionDelay: idleCompletionDelay,
      name: label,
      requiresConfirmation: requiresConfirmation,
    );
  }
}

class GoveeH5075HistoryChunk {
  const GoveeH5075HistoryChunk({
    required this.startMinutesBack,
    required this.endMinutesBack,
    required this.timeout,
    required this.idleCompletionDelay,
    this.name,
    this.requiresConfirmation = false,
  }) : assert(startMinutesBack > endMinutesBack),
       assert(startMinutesBack <= goveeH5075MaxHistoryMinutesBack),
       assert(endMinutesBack >= goveeH5075MinHistoryEndMinutesBack);

  final int startMinutesBack;
  final int endMinutesBack;
  final Duration timeout;
  final Duration idleCompletionDelay;
  final String? name;
  final bool requiresConfirmation;

  String get label => name ?? rangeLabel;

  String get rangeLabel => '$startMinutesBack -> $endMinutesBack';

  String get debugLabel => name == null ? rangeLabel : '$name ($rangeLabel)';

  String get timeoutLabel {
    final minutes = timeout.inMinutes;
    if (minutes >= 1 && timeout.inSeconds % 60 == 0) {
      return '$minutes min';
    }
    return '${timeout.inSeconds} s';
  }
}

class GoveeH5075GattProbeRequest {
  const GoveeH5075GattProbeRequest({
    required this.advertisement,
    required this.historyWindow,
    this.customHistoryChunk,
  });

  final BleAdvertisement advertisement;
  final GoveeH5075HistoryProbeWindow historyWindow;
  final GoveeH5075HistoryChunk? customHistoryChunk;

  GoveeH5075HistoryChunk get historyChunk =>
      customHistoryChunk ?? historyWindow.toChunk();
}

class GoveeH5075GattProbeSnapshot {
  GoveeH5075GattProbeSnapshot({
    required this.status,
    this.message,
    this.device,
    this.historyWindow,
    this.historyChunk,
    this.currentMeasurement,
    this.batteryPercent,
    List<GoveeH5075GattServiceInfo> services = const [],
    List<GoveeH5075GattRawEvent> rawEvents = const [],
    List<GoveeH5075HistoryRecord> historyRecords = const [],
    this.rawHistoryNotificationsOmitted = 0,
  }) : services = List.unmodifiable(services),
       rawEvents = List.unmodifiable(rawEvents),
       historyRecords = List.unmodifiable(historyRecords);

  const GoveeH5075GattProbeSnapshot.idle()
    : status = GoveeH5075GattProbeStatus.idle,
      message = null,
      device = null,
      historyWindow = null,
      historyChunk = null,
      currentMeasurement = null,
      batteryPercent = null,
      services = const [],
      rawEvents = const [],
      historyRecords = const [],
      rawHistoryNotificationsOmitted = 0;

  final GoveeH5075GattProbeStatus status;
  final String? message;
  final BleAdvertisement? device;
  final GoveeH5075HistoryProbeWindow? historyWindow;
  final GoveeH5075HistoryChunk? historyChunk;
  final GoveeH5075GattMeasurement? currentMeasurement;
  final int? batteryPercent;
  final List<GoveeH5075GattServiceInfo> services;
  final List<GoveeH5075GattRawEvent> rawEvents;
  final List<GoveeH5075HistoryRecord> historyRecords;
  final int rawHistoryNotificationsOmitted;

  bool get isRunning =>
      status == GoveeH5075GattProbeStatus.connecting ||
      status == GoveeH5075GattProbeStatus.discoveringServices ||
      status == GoveeH5075GattProbeStatus.enablingNotifications ||
      status == GoveeH5075GattProbeStatus.readingCurrent ||
      status == GoveeH5075GattProbeStatus.readingBattery ||
      status == GoveeH5075GattProbeStatus.requestingHistory;

  GoveeH5075HistoryChunk? get effectiveHistoryChunk =>
      historyChunk ?? historyWindow?.toChunk();

  GoveeH5075HistoryRangeDiagnostics? get historyDiagnostics {
    final chunk = effectiveHistoryChunk;
    if (chunk == null) {
      return null;
    }
    return GoveeH5075HistoryRangeDiagnostics.fromRecords(
      chunk: chunk,
      records: historyRecords,
    );
  }

  String toDebugText() {
    final effectiveHistoryChunk = this.effectiveHistoryChunk;
    final diagnostics = historyDiagnostics;
    final buffer = StringBuffer()
      ..writeln('status: ${status.name}')
      ..writeln('message: ${message ?? '-'}');
    final device = this.device;
    if (device != null) {
      buffer
        ..writeln('device: ${device.displayName}')
        ..writeln('id: ${device.deviceId}');
    }
    if (historyWindow != null) {
      buffer.writeln('historyWindow: ${historyWindow!.label}');
    }
    if (effectiveHistoryChunk != null) {
      buffer.writeln('historyChunk: ${effectiveHistoryChunk.rangeLabel}');
    }
    if (currentMeasurement != null) {
      buffer.writeln('current: ${currentMeasurement!.toDebugText()}');
    }
    if (batteryPercent != null) {
      buffer.writeln('battery: $batteryPercent %');
    }
    if (services.isNotEmpty) {
      buffer.writeln('services:');
      for (final service in services) {
        buffer.writeln('  ${service.uuid}');
        for (final characteristic in service.characteristics) {
          buffer.writeln(
            '    ${characteristic.uuid} [${characteristic.properties.join(', ')}]',
          );
        }
      }
    }
    if (historyRecords.isNotEmpty) {
      final uniqueRecords = diagnostics?.uniqueRecords ?? historyRecords.length;
      final oldest = diagnostics?.oldestRecord;
      final newest = diagnostics?.newestRecord;
      buffer.writeln('historyRecords: $uniqueRecords');
      buffer
        ..writeln('historyRange: ${diagnostics?.rangeLabel ?? '-'}')
        ..writeln('historyOldest: ${oldest?.toDebugText() ?? '-'}')
        ..writeln('historyNewest: ${newest?.toDebugText() ?? '-'}');
      final nextChunk = diagnostics?.nextRecommendedChunk;
      if (nextChunk != null) {
        buffer.writeln('nextHistoryChunk: ${nextChunk.rangeLabel}');
      }
      for (final record in historyRecords.take(24)) {
        buffer.writeln('  ${record.toDebugText()}');
      }
      if (historyRecords.length > 24) {
        buffer
          ..writeln('  ...')
          ..writeln('  last ${historyRecords.last.toDebugText()}');
      }
    }
    if (rawEvents.isNotEmpty) {
      buffer.writeln('rawEvents:');
      for (final event in rawEvents) {
        buffer.writeln('  ${event.toDebugText()}');
      }
    }
    if (rawHistoryNotificationsOmitted > 0) {
      buffer.writeln(
        'rawHistoryNotificationsOmitted: $rawHistoryNotificationsOmitted',
      );
    }
    return buffer.toString().trimRight();
  }
}

class GoveeH5075HistoryRangeDiagnostics {
  const GoveeH5075HistoryRangeDiagnostics({
    required this.chunk,
    required this.uniqueRecords,
    this.oldestRecord,
    this.newestRecord,
    this.nextRecommendedChunk,
  });

  factory GoveeH5075HistoryRangeDiagnostics.fromRecords({
    required GoveeH5075HistoryChunk chunk,
    required Iterable<GoveeH5075HistoryRecord> records,
  }) {
    final uniqueRecords = GoveeH5075HistoryRecords.dedupeByMinutesBack(records);
    if (uniqueRecords.isEmpty) {
      return GoveeH5075HistoryRangeDiagnostics(chunk: chunk, uniqueRecords: 0);
    }

    final oldest = uniqueRecords.reduce(
      (a, b) => a.minutesBack > b.minutesBack ? a : b,
    );
    final newest = uniqueRecords.reduce(
      (a, b) => a.minutesBack < b.minutesBack ? a : b,
    );
    final nextStartMinutesBack = newest.minutesBack - 1;
    final nextChunk = nextStartMinutesBack > chunk.endMinutesBack
        ? GoveeH5075HistoryChunk(
            startMinutesBack: nextStartMinutesBack,
            endMinutesBack: chunk.endMinutesBack,
            timeout: chunk.timeout,
            idleCompletionDelay: chunk.idleCompletionDelay,
          )
        : null;

    return GoveeH5075HistoryRangeDiagnostics(
      chunk: chunk,
      uniqueRecords: uniqueRecords.length,
      oldestRecord: oldest,
      newestRecord: newest,
      nextRecommendedChunk: nextChunk,
    );
  }

  final GoveeH5075HistoryChunk chunk;
  final int uniqueRecords;
  final GoveeH5075HistoryRecord? oldestRecord;
  final GoveeH5075HistoryRecord? newestRecord;
  final GoveeH5075HistoryChunk? nextRecommendedChunk;

  bool get hasRecords => oldestRecord != null && newestRecord != null;

  String get rangeLabel {
    final oldest = oldestRecord;
    final newest = newestRecord;
    if (oldest == null || newest == null) {
      return '-';
    }
    return '-${oldest.minutesBack}m..-${newest.minutesBack}m';
  }
}

class GoveeH5075HistoryRecords {
  const GoveeH5075HistoryRecords._();

  static List<GoveeH5075HistoryRecord> dedupeByMinutesBack(
    Iterable<GoveeH5075HistoryRecord> records,
  ) {
    final recordsByMinute = <int, GoveeH5075HistoryRecord>{};
    for (final record in records) {
      recordsByMinute.putIfAbsent(record.minutesBack, () => record);
    }
    return recordsByMinute.values.toList()
      ..sort((a, b) => b.minutesBack.compareTo(a.minutesBack));
  }
}

class GoveeH5075GattServiceInfo {
  GoveeH5075GattServiceInfo({
    required this.uuid,
    List<GoveeH5075GattCharacteristicInfo> characteristics = const [],
  }) : characteristics = List.unmodifiable(characteristics);

  final String uuid;
  final List<GoveeH5075GattCharacteristicInfo> characteristics;
}

class GoveeH5075GattCharacteristicInfo {
  GoveeH5075GattCharacteristicInfo({
    required this.uuid,
    List<String> properties = const [],
  }) : properties = List.unmodifiable(properties);

  final String uuid;
  final List<String> properties;
}

class GoveeH5075GattRawEvent {
  const GoveeH5075GattRawEvent({
    required this.timestamp,
    required this.direction,
    required this.characteristicUuid,
    required this.bytes,
    this.note,
  });

  final DateTime timestamp;
  final String direction;
  final String characteristicUuid;
  final List<int> bytes;
  final String? note;

  String toDebugText() {
    final noteText = note == null ? '' : ' ($note)';
    return '${timestamp.toIso8601String()} $direction $characteristicUuid: '
        '${formatBleBytes(bytes)}$noteText';
  }
}

class GoveeH5075GattMeasurement {
  const GoveeH5075GattMeasurement({
    required this.temperatureCelsius,
    required this.relativeHumidityPercent,
    required this.observedAt,
    this.batteryPercent,
  });

  final double temperatureCelsius;
  final double relativeHumidityPercent;
  final int? batteryPercent;
  final DateTime observedAt;

  String toDebugText() {
    final battery = batteryPercent == null ? '' : ', battery $batteryPercent %';
    return '${temperatureCelsius.toStringAsFixed(2)} C, '
        '${relativeHumidityPercent.toStringAsFixed(2)} %$battery';
  }
}

class GoveeH5075HistoryRecord {
  const GoveeH5075HistoryRecord({
    required this.minutesBack,
    required this.observedAt,
    required this.temperatureCelsius,
    required this.relativeHumidityPercent,
  });

  final int minutesBack;
  final DateTime observedAt;
  final double temperatureCelsius;
  final double relativeHumidityPercent;

  String toDebugText() {
    return '-${minutesBack}m ${observedAt.toIso8601String()} '
        '${temperatureCelsius.toStringAsFixed(1)} C '
        '${relativeHumidityPercent.toStringAsFixed(1)} %';
  }
}

abstract class GoveeH5075GattProbe {
  Stream<GoveeH5075GattProbeSnapshot> get snapshots;

  Future<void> run(GoveeH5075GattProbeRequest request);

  Future<void> abort();

  void dispose();
}

class GoveeH5075GattProtocol {
  const GoveeH5075GattProtocol();

  static const List<int> requestCurrentMeasurementCommand = [0xAA, 0x01];
  static const List<int> requestBatteryCommand = [0xAA, 0x08];
  static const List<int> requestHistoryCommand = [0x33, 0x01];

  List<int> buildCurrentMeasurementRequest() {
    return _paddedXorCommand(requestCurrentMeasurementCommand);
  }

  List<int> buildBatteryRequest() {
    return _paddedXorCommand(requestBatteryCommand);
  }

  List<int> buildHistoryRequest(GoveeH5075HistoryProbeWindow window) {
    return buildHistoryRequestForChunk(window.toChunk());
  }

  List<int> buildHistoryRequestForChunk(GoveeH5075HistoryChunk chunk) {
    return buildHistoryRequestForMinutes(
      startMinutesBack: chunk.startMinutesBack,
      endMinutesBack: chunk.endMinutesBack,
    );
  }

  List<int> buildHistoryRequestForMinutes({
    required int startMinutesBack,
    required int endMinutesBack,
  }) {
    if (startMinutesBack <= endMinutesBack) {
      throw ArgumentError.value(
        startMinutesBack,
        'startMinutesBack',
        'must be greater than endMinutesBack',
      );
    }
    if (startMinutesBack > goveeH5075MaxHistoryMinutesBack) {
      throw ArgumentError.value(
        startMinutesBack,
        'startMinutesBack',
        'must not exceed the experimental H5075 30-day probe window',
      );
    }
    if (endMinutesBack < goveeH5075MinHistoryEndMinutesBack) {
      throw ArgumentError.value(
        endMinutesBack,
        'endMinutesBack',
        'must be at least one minute back',
      );
    }
    return _paddedXorCommand([
      ...requestHistoryCommand,
      startMinutesBack >> 8,
      startMinutesBack & 0xFF,
      endMinutesBack >> 8,
      endMinutesBack & 0xFF,
    ]);
  }

  GoveeH5075GattMeasurement? parseCurrentMeasurementResponse(
    List<int> bytes, {
    required DateTime observedAt,
  }) {
    if (bytes.length < 7 || bytes[0] != 0xAA || bytes[1] != 0x01) {
      return null;
    }
    final temperatureRaw =
        (bytes[2].toUnsigned(8) << 8) | bytes[3].toUnsigned(8);
    final humidityRaw = (bytes[4].toUnsigned(8) << 8) | bytes[5].toUnsigned(8);
    final battery = _validBattery(bytes[6]);
    return GoveeH5075GattMeasurement(
      temperatureCelsius: _signed16(temperatureRaw) / 100.0,
      relativeHumidityPercent: humidityRaw / 100.0,
      batteryPercent: battery,
      observedAt: observedAt,
    );
  }

  int? parseBatteryResponse(List<int> bytes) {
    if (bytes.length < 3 || bytes[0] != 0xAA || bytes[1] != 0x08) {
      return null;
    }
    return _validBattery(bytes[2]);
  }

  List<GoveeH5075HistoryRecord> parseHistoryNotification(
    List<int> bytes, {
    required DateTime downloadStartedAt,
  }) {
    if (bytes.length < 5) {
      return const [];
    }
    final firstMinutesBack =
        (bytes[0].toUnsigned(8) << 8) | bytes[1].toUnsigned(8);
    final records = <GoveeH5075HistoryRecord>[];
    for (var index = 0; index < 6; index += 1) {
      final start = 2 + index * 3;
      if (start + 2 >= bytes.length) {
        break;
      }
      final recordBytes = bytes.sublist(start, start + 3);
      if (recordBytes.every((byte) => byte.toUnsigned(8) == 0xFF)) {
        continue;
      }
      final decoded = decodePackedTemperatureHumidity(recordBytes);
      if (decoded == null) {
        continue;
      }
      final minutesBack = firstMinutesBack - index;
      if (minutesBack < 0) {
        continue;
      }
      records.add(
        GoveeH5075HistoryRecord(
          minutesBack: minutesBack,
          observedAt: downloadStartedAt.subtract(
            Duration(minutes: minutesBack),
          ),
          temperatureCelsius: decoded.temperatureCelsius,
          relativeHumidityPercent: decoded.relativeHumidityPercent,
        ),
      );
    }
    return records;
  }

  GoveeH5075PackedMeasurement? decodePackedTemperatureHumidity(
    List<int> bytes,
  ) {
    if (bytes.length < 3) {
      return null;
    }
    final encoded =
        (bytes[0].toUnsigned(8) << 16) |
        (bytes[1].toUnsigned(8) << 8) |
        bytes[2].toUnsigned(8);
    final isNegative = (encoded & 0x800000) != 0;
    final magnitude = encoded & 0x7FFFFF;
    final humidityTenths = magnitude % 1000;
    final temperatureTenths = magnitude ~/ 1000;
    final temperatureCelsius =
        (isNegative ? -temperatureTenths : temperatureTenths) / 10.0;
    final relativeHumidityPercent = humidityTenths / 10.0;
    if (temperatureCelsius < -40 ||
        temperatureCelsius > 80 ||
        relativeHumidityPercent < 0 ||
        relativeHumidityPercent > 100) {
      return null;
    }
    return GoveeH5075PackedMeasurement(
      temperatureCelsius: temperatureCelsius,
      relativeHumidityPercent: relativeHumidityPercent,
    );
  }

  List<int> _paddedXorCommand(List<int> prefix) {
    if (prefix.length > 19) {
      throw ArgumentError.value(prefix, 'prefix', 'must fit in 19 bytes');
    }
    final bytes = List<int>.filled(20, 0);
    for (var index = 0; index < prefix.length; index += 1) {
      bytes[index] = prefix[index].toUnsigned(8);
    }
    var checksum = 0;
    for (var index = 0; index < bytes.length - 1; index += 1) {
      checksum ^= bytes[index].toUnsigned(8);
    }
    bytes[19] = checksum;
    return bytes;
  }

  int? _validBattery(int value) {
    final battery = value.toUnsigned(8);
    return battery > 0 && battery <= 100 ? battery : null;
  }

  int _signed16(int value) {
    final unsigned = value.toUnsigned(16);
    return (unsigned & 0x8000) == 0 ? unsigned : unsigned - 0x10000;
  }
}

class GoveeH5075PackedMeasurement {
  const GoveeH5075PackedMeasurement({
    required this.temperatureCelsius,
    required this.relativeHumidityPercent,
  });

  final double temperatureCelsius;
  final double relativeHumidityPercent;
}
