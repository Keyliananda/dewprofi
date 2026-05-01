import '../../core/sensors/ble_advertisement.dart';
import '../../core/sensors/sensor_measurement.dart';

const int goveeManufacturerCompanyId = 0xEC88;

enum GoveeH5075ParseStatus { decoded, candidate, ignored, invalidPayload }

class GoveeH5075Discovery {
  const GoveeH5075Discovery({
    required this.advertisement,
    required this.status,
    required this.reason,
    this.measurement,
  });

  final BleAdvertisement advertisement;
  final GoveeH5075ParseStatus status;
  final String reason;
  final LiveSensorMeasurement? measurement;

  bool get isCandidate =>
      status == GoveeH5075ParseStatus.decoded ||
      status == GoveeH5075ParseStatus.candidate ||
      status == GoveeH5075ParseStatus.invalidPayload;
}

class GoveeH5075AdvertisementParser {
  const GoveeH5075AdvertisementParser();

  List<GoveeH5075Discovery> discover(
    Iterable<BleAdvertisement> advertisements,
  ) {
    return [
      for (final advertisement in advertisements) parse(advertisement),
    ].where((discovery) => discovery.isCandidate).toList();
  }

  GoveeH5075Discovery parse(BleAdvertisement advertisement) {
    final name = advertisement.deviceName?.toUpperCase() ?? '';
    final nameLooksLikeH5075 =
        name.contains('H5075') || name.contains('GVH5075');
    final manufacturerPayload = _goveePayload(advertisement);

    if (!nameLooksLikeH5075 && manufacturerPayload == null) {
      return GoveeH5075Discovery(
        advertisement: advertisement,
        status: GoveeH5075ParseStatus.ignored,
        reason: 'Kein H5075-Name und keine Govee-Manufacturer-Daten.',
      );
    }

    if (manufacturerPayload == null) {
      return GoveeH5075Discovery(
        advertisement: advertisement,
        status: GoveeH5075ParseStatus.candidate,
        reason:
            'Name sieht nach H5075 aus, aber keine auswertbare Manufacturer-Payload vorhanden.',
      );
    }

    final measurement = _decodeKnownH5075Layout(
      advertisement,
      manufacturerPayload,
    );
    if (measurement == null) {
      return GoveeH5075Discovery(
        advertisement: advertisement,
        status: GoveeH5075ParseStatus.invalidPayload,
        reason:
            'Govee-Payload erkannt, aber Layout/Werte sind noch nicht gesichert.',
      );
    }

    return GoveeH5075Discovery(
      advertisement: advertisement,
      status: GoveeH5075ParseStatus.decoded,
      reason: 'H5075-Livewerte aus passiver Advertisement-Payload dekodiert.',
      measurement: measurement,
    );
  }

  List<int>? _goveePayload(BleAdvertisement advertisement) {
    for (final data in advertisement.manufacturerData) {
      if (data.companyId == goveeManufacturerCompanyId) {
        return data.data;
      }
    }
    return null;
  }

  LiveSensorMeasurement? _decodeKnownH5075Layout(
    BleAdvertisement advertisement,
    List<int> payload,
  ) {
    if (payload.length < 5) {
      return null;
    }

    final encoded =
        (payload[1].toUnsigned(8) << 16) |
        (payload[2].toUnsigned(8) << 8) |
        payload[3].toUnsigned(8);
    final isNegative = (encoded & 0x800000) != 0;
    final magnitude = encoded & 0x7FFFFF;
    final humidityTenths = magnitude % 1000;
    final temperatureCelsius = (isNegative ? -magnitude : magnitude) / 10000.0;
    final relativeHumidityPercent = humidityTenths / 10.0;
    final rawBatteryPercent = payload[4].toUnsigned(8);
    final batteryPercent = rawBatteryPercent == 0 ? null : rawBatteryPercent;

    if (temperatureCelsius < -40 ||
        temperatureCelsius > 80 ||
        relativeHumidityPercent < 0 ||
        relativeHumidityPercent > 100 ||
        rawBatteryPercent > 100) {
      return null;
    }

    return LiveSensorMeasurement(
      temperatureCelsius: temperatureCelsius,
      relativeHumidityPercent: relativeHumidityPercent,
      batteryPercent: batteryPercent,
      observedAt: advertisement.observedAt,
      receivedAt: DateTime.now(),
      deviceId: advertisement.deviceId,
      deviceName: advertisement.deviceName,
      source: SensorMeasurementSource.bleAdvertisement,
      rawAdvertisement: advertisement,
    );
  }
}
