class BleAdvertisement {
  BleAdvertisement({
    required this.deviceId,
    required this.observedAt,
    this.deviceName,
    this.rssi,
    this.txPowerLevel,
    this.appearance,
    this.connectable,
    List<BleManufacturerData> manufacturerData = const [],
    List<BleServiceData> serviceData = const [],
    List<String> serviceUuids = const [],
  }) : manufacturerData = List.unmodifiable(manufacturerData),
       serviceData = List.unmodifiable(serviceData),
       serviceUuids = List.unmodifiable(serviceUuids);

  final String deviceId;
  final String? deviceName;
  final int? rssi;
  final int? txPowerLevel;
  final int? appearance;
  final bool? connectable;
  final DateTime observedAt;
  final List<BleManufacturerData> manufacturerData;
  final List<BleServiceData> serviceData;
  final List<String> serviceUuids;

  String get displayName {
    final name = deviceName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return deviceId;
  }

  bool get hasRawPayload =>
      manufacturerData.isNotEmpty || serviceData.isNotEmpty;

  Iterable<RawBlePayload> get rawPayloads sync* {
    for (final data in manufacturerData) {
      yield RawBlePayload(
        kind: 'manufacturer',
        id: data.companyIdHex,
        bytes: data.data,
      );
    }
    for (final data in serviceData) {
      yield RawBlePayload(kind: 'service', id: data.uuid, bytes: data.data);
    }
  }

  String toDebugText() {
    final buffer = StringBuffer()
      ..writeln('device: $displayName')
      ..writeln('id: $deviceId')
      ..writeln('rssi: ${rssi ?? '-'}')
      ..writeln('seen: ${observedAt.toIso8601String()}');
    if (txPowerLevel != null) {
      buffer.writeln('txPower: $txPowerLevel');
    }
    if (appearance != null) {
      buffer.writeln('appearance: $appearance');
    }
    if (connectable != null) {
      buffer.writeln('connectable: $connectable');
    }
    if (serviceUuids.isNotEmpty) {
      buffer.writeln('serviceUuids: ${serviceUuids.join(', ')}');
    }
    for (final payload in rawPayloads) {
      buffer.writeln('${payload.kind} ${payload.id}: ${payload.hex}');
    }
    if (!hasRawPayload) {
      buffer.writeln('rawPayload: none exposed by platform/plugin');
    }
    return buffer.toString().trimRight();
  }
}

class BleManufacturerData {
  BleManufacturerData({required this.companyId, required List<int> data})
    : data = List.unmodifiable(data);

  final int companyId;
  final List<int> data;

  String get companyIdHex => formatBleCompanyId(companyId);
  String get dataHex => formatBleBytes(data);
}

class BleServiceData {
  BleServiceData({required this.uuid, required List<int> data})
    : data = List.unmodifiable(data);

  final String uuid;
  final List<int> data;

  String get dataHex => formatBleBytes(data);
}

class RawBlePayload {
  RawBlePayload({
    required this.kind,
    required this.id,
    required List<int> bytes,
  }) : bytes = List.unmodifiable(bytes);

  final String kind;
  final String id;
  final List<int> bytes;

  String get hex => formatBleBytes(bytes);
}

String formatBleCompanyId(int companyId) {
  return '0x${companyId.toRadixString(16).padLeft(4, '0').toUpperCase()}';
}

String formatBleBytes(Iterable<int> bytes) {
  return bytes
      .map((byte) => byte.toUnsigned(8).toRadixString(16).padLeft(2, '0'))
      .join(' ')
      .toUpperCase();
}
