import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/sensors/ble_advertisement.dart';
import 'ble_advertisement_scanner.dart';

class FlutterBluePlusBleAdvertisementScanner
    implements BleAdvertisementScanner {
  FlutterBluePlusBleAdvertisementScanner({
    this.scanTimeout = const Duration(seconds: 20),
    this.enableMacosScan = const bool.fromEnvironment(
      'DEWPROFI_ENABLE_MACOS_FBP_BLE_SCAN',
    ),
  });

  final Duration scanTimeout;
  final bool enableMacosScan;
  final _controller = StreamController<BleScanSnapshot>.broadcast();
  final Map<String, BleAdvertisement> _advertisements = {};
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  BleScannerStatus _status = BleScannerStatus.idle;
  String? _message;
  bool _disposed = false;

  @override
  Stream<BleScanSnapshot> get snapshots async* {
    yield BleScanSnapshot(
      status: _status,
      advertisements: _advertisements.values.toList(),
      message: _message,
    );
    yield* _controller.stream;
  }

  @override
  Future<void> startScan() async {
    if (_disposed) {
      return;
    }
    _advertisements.clear();
    _emit(BleScannerStatus.scanning, 'Bluetooth-Scan startet.');

    try {
      if (defaultTargetPlatform == TargetPlatform.macOS && !enableMacosScan) {
        _emit(
          BleScannerStatus.unsupported,
          'macOS-Scan ist im FlutterBluePlus-Adapter deaktiviert; '
          'CoreBluetooth-Probe oder iOS-Test verwenden.',
        );
        return;
      }

      if (!await FlutterBluePlus.isSupported) {
        _emit(
          BleScannerStatus.unsupported,
          'Bluetooth LE wird auf diesem Geraet nicht unterstuetzt.',
        );
        return;
      }

      final adapterState = await _adapterState();
      if (adapterState == BluetoothAdapterState.unauthorized) {
        _emit(BleScannerStatus.unauthorized, 'Bluetooth-Berechtigung fehlt.');
        return;
      }
      if (adapterState == BluetoothAdapterState.off) {
        _emit(BleScannerStatus.poweredOff, 'Bluetooth ist ausgeschaltet.');
        return;
      }
      if (adapterState != BluetoothAdapterState.on) {
        _emit(
          BleScannerStatus.error,
          'Bluetooth ist noch nicht scanbereit (${adapterState.name}).',
        );
        return;
      }

      await _scanResultsSubscription?.cancel();
      await _isScanningSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.onScanResults.listen(
        _handleScanResults,
        onError: (Object error) {
          _emit(BleScannerStatus.error, 'Scan-Fehler: $error');
        },
      );
      _isScanningSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
        if (!isScanning && _status == BleScannerStatus.scanning) {
          _emit(BleScannerStatus.idle, 'Scan beendet.');
        }
      });

      await FlutterBluePlus.startScan(
        timeout: scanTimeout,
        continuousUpdates: true,
        continuousDivisor: 3,
      );
      _emit(BleScannerStatus.scanning, 'Scan laeuft.');
    } on FlutterBluePlusException catch (error) {
      _emit(BleScannerStatus.error, 'Bluetooth-Fehler: ${error.description}');
    } on Object catch (error) {
      _emit(
        BleScannerStatus.error,
        'Bluetooth-Scan konnte nicht gestartet werden: $error',
      );
    }
  }

  @override
  Future<void> stopScan() async {
    if (_disposed) {
      return;
    }
    try {
      await FlutterBluePlus.stopScan();
    } finally {
      _emit(BleScannerStatus.idle, 'Scan gestoppt.');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _controller.close();
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      final advertisement = _fromScanResult(result);
      _advertisements[advertisement.deviceId] = advertisement;
      _logGoveeCandidate(advertisement);
    }
    _emit(_status, _message);
  }

  Future<BluetoothAdapterState> _adapterState() async {
    final currentState = FlutterBluePlus.adapterStateNow;
    if (currentState != BluetoothAdapterState.unknown) {
      return currentState;
    }
    try {
      return await FlutterBluePlus.adapterState
          .where((state) => state != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 3));
    } on TimeoutException {
      return BluetoothAdapterState.unknown;
    }
  }

  BleAdvertisement _fromScanResult(ScanResult result) {
    final data = result.advertisementData;
    final name = data.advName.trim().isNotEmpty
        ? data.advName
        : result.device.platformName.trim().isNotEmpty
        ? result.device.platformName
        : null;

    return BleAdvertisement(
      deviceId: result.device.remoteId.str,
      deviceName: name,
      rssi: result.rssi,
      txPowerLevel: data.txPowerLevel,
      appearance: data.appearance,
      connectable: data.connectable,
      observedAt: result.timeStamp,
      manufacturerData: [
        for (final entry in data.manufacturerData.entries)
          BleManufacturerData(companyId: entry.key, data: entry.value),
      ],
      serviceData: [
        for (final entry in data.serviceData.entries)
          BleServiceData(uuid: entry.key.str, data: entry.value),
      ],
      serviceUuids: [for (final uuid in data.serviceUuids) uuid.str],
    );
  }

  void _emit(BleScannerStatus status, String? message) {
    _status = status;
    _message = message;
    if (_disposed || _controller.isClosed) {
      return;
    }
    _controller.add(
      BleScanSnapshot(
        status: _status,
        advertisements: _advertisements.values.toList()
          ..sort((a, b) => b.observedAt.compareTo(a.observedAt)),
        message: _message,
      ),
    );
  }

  void _logGoveeCandidate(BleAdvertisement advertisement) {
    final name = advertisement.deviceName?.toUpperCase() ?? '';
    final hasGoveeManufacturerData = advertisement.manufacturerData.any(
      (data) => data.companyId == 0xEC88,
    );
    final looksLikeGovee =
        name.contains('H5075') ||
        name.contains('GVH5075') ||
        name.contains('GOVE');
    if (!hasGoveeManufacturerData && !looksLikeGovee) {
      return;
    }
    debugPrint('Govee/H5075 BLE candidate:\\n${advertisement.toDebugText()}');
  }
}
