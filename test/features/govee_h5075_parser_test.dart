import 'package:dewprofi/core/sensors/ble_advertisement.dart';
import 'package:dewprofi/features/govee/govee_h5075_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = GoveeH5075AdvertisementParser();

  test('decodes a known H5075 manufacturer payload layout', () {
    final advertisement = _advertisement(
      name: 'GVH5075_1234',
      manufacturerData: [
        BleManufacturerData(
          companyId: goveeManufacturerCompanyId,
          data: const [0x00, 0x02, 0x92, 0x76, 0x57, 0x00],
        ),
      ],
    );

    final discovery = parser.parse(advertisement);

    expect(discovery.status, GoveeH5075ParseStatus.decoded);
    expect(discovery.measurement?.temperatureCelsius, closeTo(16.8566, 0.0001));
    expect(discovery.measurement?.relativeHumidityPercent, 56.6);
    expect(discovery.measurement?.batteryPercent, 87);
    expect(discovery.measurement?.rawAdvertisement, same(advertisement));
  });

  test('decodes the first real macOS H5075 discovery sample', () {
    final discovery = parser.parse(
      _advertisement(
        name: 'GVH5075_ACC0',
        manufacturerData: [
          BleManufacturerData(
            companyId: goveeManufacturerCompanyId,
            data: const [0x00, 0x02, 0x92, 0x76, 0x00, 0x00],
          ),
        ],
      ),
    );

    expect(discovery.status, GoveeH5075ParseStatus.decoded);
    expect(discovery.measurement?.temperatureCelsius, closeTo(16.8566, 0.0001));
    expect(discovery.measurement?.relativeHumidityPercent, 56.6);
    expect(discovery.measurement?.batteryPercent, isNull);
  });

  test('keeps battery byte zero unknown until it is validated', () {
    final discovery = parser.parse(
      _advertisement(
        name: 'GVH5075_ACC0',
        manufacturerData: [
          BleManufacturerData(
            companyId: goveeManufacturerCompanyId,
            data: const [0x00, 0x02, 0x92, 0x76, 0x00, 0x00],
          ),
        ],
      ),
    );

    expect(discovery.status, GoveeH5075ParseStatus.decoded);
    expect(discovery.measurement?.batteryPercent, isNull);
  });

  test('keeps name-only H5075 candidates as raw debug samples', () {
    final discovery = parser.parse(_advertisement(name: 'GVH5075_ABCD'));

    expect(discovery.status, GoveeH5075ParseStatus.candidate);
    expect(discovery.measurement, isNull);
    expect(discovery.isCandidate, isTrue);
  });

  test('rejects implausible Govee payloads without inventing values', () {
    final discovery = parser.parse(
      _advertisement(
        name: 'GVH5075_ABCD',
        manufacturerData: [
          BleManufacturerData(
            companyId: goveeManufacturerCompanyId,
            data: const [0x00, 0x0D, 0x7F, 0xFF, 0xFF, 0xFF, 0x02],
          ),
        ],
      ),
    );

    expect(discovery.status, GoveeH5075ParseStatus.invalidPayload);
    expect(discovery.measurement, isNull);
  });
}

BleAdvertisement _advertisement({
  String? name,
  List<BleManufacturerData> manufacturerData = const [],
}) {
  return BleAdvertisement(
    deviceId: 'AA:BB:CC:DD:EE:FF',
    deviceName: name,
    rssi: -61,
    observedAt: DateTime(2026, 5, 1, 12),
    manufacturerData: manufacturerData,
  );
}
