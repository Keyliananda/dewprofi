import 'package:dewprofi/features/sensors/ble_advertisement_scanner.dart';
import 'package:dewprofi/features/sensors/flutter_blue_plus_ble_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'macOS scan is gated before FlutterBluePlus is invoked by default',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final scanner = FlutterBluePlusBleAdvertisementScanner();
      addTearDown(scanner.dispose);

      final snapshots = <BleScanSnapshot>[];
      final subscription = scanner.snapshots.listen(snapshots.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      await scanner.startScan();
      await Future<void>.delayed(Duration.zero);

      expect(snapshots.last.status, BleScannerStatus.unsupported);
      expect(snapshots.last.advertisements, isEmpty);
      expect(snapshots.last.message, contains('macOS-Scan'));
    },
  );
}
