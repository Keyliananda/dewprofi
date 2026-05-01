import 'ble_advertisement.dart';

enum SensorMeasurementSource {
  bleAdvertisement('ble-advertisement');

  const SensorMeasurementSource(this.label);

  final String label;
}

class LiveSensorMeasurement {
  const LiveSensorMeasurement({
    required this.temperatureCelsius,
    required this.relativeHumidityPercent,
    required this.observedAt,
    required this.receivedAt,
    required this.deviceId,
    required this.source,
    required this.rawAdvertisement,
    this.batteryPercent,
    this.deviceName,
  });

  final double temperatureCelsius;
  final double relativeHumidityPercent;
  final int? batteryPercent;
  final DateTime observedAt;
  final DateTime receivedAt;
  final String deviceId;
  final String? deviceName;
  final SensorMeasurementSource source;
  final BleAdvertisement rawAdvertisement;

  String get label {
    final name = deviceName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'BLE-Sensor $deviceId';
  }
}
