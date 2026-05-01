import '../../core/sensors/ble_advertisement.dart';

enum BleScannerStatus {
  idle,
  scanning,
  unsupported,
  unauthorized,
  poweredOff,
  error,
}

class BleScanSnapshot {
  BleScanSnapshot({
    required this.status,
    required List<BleAdvertisement> advertisements,
    this.message,
  }) : advertisements = List.unmodifiable(advertisements);

  const BleScanSnapshot.idle()
    : status = BleScannerStatus.idle,
      advertisements = const [],
      message = null;

  final BleScannerStatus status;
  final List<BleAdvertisement> advertisements;
  final String? message;

  bool get isScanning => status == BleScannerStatus.scanning;
}

abstract class BleAdvertisementScanner {
  Stream<BleScanSnapshot> get snapshots;

  Future<void> startScan();

  Future<void> stopScan();

  void dispose();
}
