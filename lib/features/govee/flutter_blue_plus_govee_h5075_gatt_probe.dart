import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'govee_h5075_gatt_probe.dart';

class FlutterBluePlusGoveeH5075GattProbe implements GoveeH5075GattProbe {
  FlutterBluePlusGoveeH5075GattProbe({
    this.enableMacosGatt = const bool.fromEnvironment(
      'DEWPROFI_ENABLE_MACOS_FBP_GATT_PROBE',
    ),
    this.connectionTimeout = const Duration(seconds: 15),
    this.commandSettleDelay = const Duration(milliseconds: 700),
    GoveeH5075GattProtocol protocol = const GoveeH5075GattProtocol(),
  }) : _protocol = protocol;

  static const int _maxRawHistoryNotificationsToKeep = 8;

  final bool enableMacosGatt;
  final Duration connectionTimeout;
  final Duration commandSettleDelay;
  final GoveeH5075GattProtocol _protocol;

  final _controller = StreamController<GoveeH5075GattProbeSnapshot>.broadcast();
  final _rawEvents = <GoveeH5075GattRawEvent>[];
  final _historyRecords = <GoveeH5075HistoryRecord>[];
  final _historyMinutesBack = <int>{};
  final _services = <GoveeH5075GattServiceInfo>[];
  final _subscriptions = <StreamSubscription<List<int>>>[];

  BluetoothDevice? _activeDevice;
  GoveeH5075GattProbeRequest? _request;
  GoveeH5075GattMeasurement? _currentMeasurement;
  int? _batteryPercent;
  int _rawHistoryNotificationsKept = 0;
  int _rawHistoryNotificationsOmitted = 0;
  bool _disposed = false;
  bool _aborted = false;
  DateTime? _historyDownloadStartedAt;
  Timer? _historyIdleTimer;
  Completer<void>? _historyComplete;
  String? _historyCompletionMessage;
  GoveeH5075GattProbeStatus _status = GoveeH5075GattProbeStatus.idle;
  String? _message;

  @override
  Stream<GoveeH5075GattProbeSnapshot> get snapshots async* {
    yield const GoveeH5075GattProbeSnapshot.idle();
    yield* _controller.stream;
  }

  @override
  Future<void> run(GoveeH5075GattProbeRequest request) async {
    if (_disposed) {
      return;
    }
    if (_snapshot().isRunning) {
      return;
    }

    _request = request;
    _rawEvents.clear();
    _historyRecords.clear();
    _historyMinutesBack.clear();
    _services.clear();
    _currentMeasurement = null;
    _batteryPercent = null;
    _rawHistoryNotificationsKept = 0;
    _rawHistoryNotificationsOmitted = 0;
    _historyDownloadStartedAt = null;
    _historyIdleTimer?.cancel();
    _historyIdleTimer = null;
    _historyComplete = null;
    _historyCompletionMessage = null;
    _aborted = false;

    if (defaultTargetPlatform == TargetPlatform.macOS && !enableMacosGatt) {
      _emit(
        GoveeH5075GattProbeStatus.unsupported,
        'macOS-GATT ist im FlutterBluePlus-Adapter deaktiviert; iPhone-Probe oder isoliertes Tool verwenden.',
      );
      return;
    }

    final device = BluetoothDevice.fromId(request.advertisement.deviceId);
    _activeDevice = device;
    final historyChunk = request.historyChunk;

    try {
      _emit(GoveeH5075GattProbeStatus.connecting, 'GATT-Verbindung startet.');
      await device.connect(
        license: License.free,
        timeout: connectionTimeout,
        mtu: null,
      );
      _ensureNotAborted();

      _emit(
        GoveeH5075GattProbeStatus.discoveringServices,
        'Services werden inventarisiert.',
      );
      final services = await device.discoverServices(timeout: 12);
      _services
        ..clear()
        ..addAll(_inventory(services));
      final chars = _findKnownCharacteristics(services);
      _ensureNotAborted();

      _emit(
        GoveeH5075GattProbeStatus.enablingNotifications,
        'Notifications fuer bekannte Response-Characteristics werden aktiviert.',
      );
      await _listenAndNotify(chars.device, goveeH5075DeviceCharacteristicUuid);
      await _listenAndNotify(
        chars.command,
        goveeH5075CommandCharacteristicUuid,
      );
      await _listenAndNotify(
        chars.history,
        goveeH5075HistoryCharacteristicUuid,
      );
      _ensureNotAborted();

      _emit(
        GoveeH5075GattProbeStatus.readingCurrent,
        'Aktuelle Messung und Batterie werden angefragt.',
      );
      await _writeAllowlisted(
        chars.command,
        _protocol.buildCurrentMeasurementRequest(),
        note: 'allowlisted current measurement request aa01',
      );
      await Future<void>.delayed(commandSettleDelay);
      _ensureNotAborted();

      _emit(
        GoveeH5075GattProbeStatus.readingBattery,
        'Batterie wird gegen GATT-Device-Characteristic gegengeprueft.',
      );
      await _writeAllowlisted(
        chars.device,
        _protocol.buildBatteryRequest(),
        note: 'allowlisted battery request aa08',
      );
      await Future<void>.delayed(commandSettleDelay);
      _ensureNotAborted();

      _emit(
        GoveeH5075GattProbeStatus.requestingHistory,
        'History-Chunk ${historyChunk.debugLabel} wird angefragt; Timeout ${historyChunk.timeoutLabel}.',
      );
      _historyDownloadStartedAt = DateTime.now();
      _historyComplete = Completer<void>();
      await _writeAllowlisted(
        chars.command,
        _protocol.buildHistoryRequestForChunk(historyChunk),
        note: 'allowlisted history request 3301 ${historyChunk.rangeLabel}',
      );
      await _historyComplete!.future.timeout(historyChunk.timeout);
      _ensureNotAborted();

      _emit(
        GoveeH5075GattProbeStatus.completed,
        _historyCompletionMessage ??
            'GATT-Probe abgeschlossen; Verbindung wird getrennt.',
      );
    } on _GattProbeAborted {
      _emit(GoveeH5075GattProbeStatus.aborted, 'GATT-Probe abgebrochen.');
    } on TimeoutException catch (error) {
      _emit(GoveeH5075GattProbeStatus.error, 'GATT-Probe Timeout: $error');
    } on FlutterBluePlusException catch (error) {
      _emit(
        GoveeH5075GattProbeStatus.error,
        'Bluetooth-Fehler: ${error.description}',
      );
    } on Object catch (error) {
      _emit(GoveeH5075GattProbeStatus.error, 'GATT-Probe Fehler: $error');
    } finally {
      _historyIdleTimer?.cancel();
      _historyIdleTimer = null;
      await _cleanupConnection();
    }
  }

  @override
  Future<void> abort() async {
    _aborted = true;
    _historyIdleTimer?.cancel();
    _historyIdleTimer = null;
    await _cleanupConnection();
    _emit(GoveeH5075GattProbeStatus.aborted, 'GATT-Probe abgebrochen.');
  }

  @override
  void dispose() {
    _disposed = true;
    _historyIdleTimer?.cancel();
    _cleanupConnection();
    _controller.close();
  }

  Future<void> _listenAndNotify(
    BluetoothCharacteristic characteristic,
    String uuid,
  ) async {
    final subscription = characteristic.onValueReceived.listen(
      (bytes) => _handleNotification(uuid, bytes),
      onError: (Object error) {
        _emit(
          GoveeH5075GattProbeStatus.error,
          'Notification-Fehler auf $uuid: $error',
        );
      },
    );
    _subscriptions.add(subscription);
    await characteristic.setNotifyValue(true, timeout: 8);
  }

  void _handleNotification(String characteristicUuid, List<int> bytes) {
    final now = DateTime.now();
    _addRawEvent(
      GoveeH5075GattRawEvent(
        timestamp: now,
        direction: '<-- notify',
        characteristicUuid: characteristicUuid,
        bytes: List<int>.unmodifiable(bytes),
      ),
      isHistoryNotification:
          characteristicUuid == goveeH5075HistoryCharacteristicUuid,
    );

    if (characteristicUuid == goveeH5075CommandCharacteristicUuid) {
      final current = _protocol.parseCurrentMeasurementResponse(
        bytes,
        observedAt: now,
      );
      if (current != null) {
        _currentMeasurement = current;
        _batteryPercent = current.batteryPercent ?? _batteryPercent;
      }
      if (bytes.length >= 2 && bytes[0] == 0xEE && bytes[1] == 0x01) {
        _completeHistoryIfNeeded();
      }
    } else if (characteristicUuid == goveeH5075DeviceCharacteristicUuid) {
      _batteryPercent =
          _protocol.parseBatteryResponse(bytes) ?? _batteryPercent;
    } else if (characteristicUuid == goveeH5075HistoryCharacteristicUuid) {
      final startedAt = _historyDownloadStartedAt ?? now;
      final addedRecords = _addUniqueHistoryRecords(
        _protocol.parseHistoryNotification(bytes, downloadStartedAt: startedAt),
      );
      if (addedRecords > 0) {
        _armHistoryIdleCompletion();
        _completeHistoryIfTargetReached();
      }
    }
    _emit(_status, _message);
  }

  int _addUniqueHistoryRecords(List<GoveeH5075HistoryRecord> records) {
    var added = 0;
    for (final record in records) {
      if (_historyMinutesBack.add(record.minutesBack)) {
        _historyRecords.add(record);
        added += 1;
      }
    }
    return added;
  }

  void _completeHistoryIfTargetReached() {
    final request = _request;
    if (request == null || _historyRecords.isEmpty) {
      return;
    }
    final historyChunk = request.historyChunk;
    final minMinutesBack = _historyRecords
        .map((record) => record.minutesBack)
        .reduce((a, b) => a < b ? a : b);
    if (minMinutesBack <= historyChunk.endMinutesBack) {
      _completeHistoryIfNeeded(
        'History-Chunk ${historyChunk.debugLabel} vollstaendig bis -${historyChunk.endMinutesBack}m gelesen; ${_historyRecords.length} eindeutige Records gesichert.',
      );
    }
  }

  void _armHistoryIdleCompletion() {
    final request = _request;
    final complete = _historyComplete;
    if (request == null ||
        complete == null ||
        complete.isCompleted ||
        _historyRecords.isEmpty) {
      return;
    }
    final historyChunk = request.historyChunk;
    _historyIdleTimer?.cancel();
    _historyIdleTimer = Timer(historyChunk.idleCompletionDelay, () {
      final complete = _historyComplete;
      if (_disposed ||
          _aborted ||
          complete == null ||
          complete.isCompleted ||
          _historyRecords.isEmpty) {
        return;
      }
      _completeHistoryIfNeeded(
        'History-Datenstrom seit ${historyChunk.idleCompletionDelay.inSeconds} s ruhig; ${_historyRecords.length} Records gesichert, Verbindung wird getrennt.',
      );
    });
  }

  void _completeHistoryIfNeeded([String? message]) {
    final complete = _historyComplete;
    if (complete != null && !complete.isCompleted) {
      _historyCompletionMessage = message;
      _historyIdleTimer?.cancel();
      _historyIdleTimer = null;
      complete.complete();
    }
  }

  Future<void> _writeAllowlisted(
    BluetoothCharacteristic characteristic,
    List<int> bytes, {
    required String note,
  }) async {
    _addRawEvent(
      GoveeH5075GattRawEvent(
        timestamp: DateTime.now(),
        direction: '--> write-with-response',
        characteristicUuid: characteristic.uuid.str,
        bytes: List<int>.unmodifiable(bytes),
        note: note,
      ),
    );
    await characteristic.write(bytes, withoutResponse: false, timeout: 8);
  }

  void _addRawEvent(
    GoveeH5075GattRawEvent event, {
    bool isHistoryNotification = false,
  }) {
    if (isHistoryNotification) {
      if (_rawHistoryNotificationsKept >= _maxRawHistoryNotificationsToKeep) {
        _rawHistoryNotificationsOmitted += 1;
        return;
      }
      _rawHistoryNotificationsKept += 1;
    }
    _rawEvents.add(event);
  }

  List<GoveeH5075GattServiceInfo> _inventory(List<BluetoothService> services) {
    return [
      for (final service in services)
        GoveeH5075GattServiceInfo(
          uuid: service.uuid.str,
          characteristics: [
            for (final characteristic in service.characteristics)
              GoveeH5075GattCharacteristicInfo(
                uuid: characteristic.uuid.str,
                properties: _properties(characteristic.properties),
              ),
          ],
        ),
    ];
  }

  List<String> _properties(CharacteristicProperties properties) {
    return [
      if (properties.read) 'read',
      if (properties.write) 'write',
      if (properties.writeWithoutResponse) 'writeWithoutResponse',
      if (properties.notify) 'notify',
      if (properties.indicate) 'indicate',
    ];
  }

  _KnownCharacteristics _findKnownCharacteristics(
    List<BluetoothService> services,
  ) {
    final byUuid = <String, BluetoothCharacteristic>{};
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        byUuid[characteristic.uuid.str.toLowerCase()] = characteristic;
      }
    }
    BluetoothCharacteristic requiredChar(String uuid) {
      final characteristic = byUuid[uuid.toLowerCase()];
      if (characteristic == null) {
        throw StateError('Bekannte H5075-Characteristic fehlt: $uuid');
      }
      return characteristic;
    }

    return _KnownCharacteristics(
      device: requiredChar(goveeH5075DeviceCharacteristicUuid),
      command: requiredChar(goveeH5075CommandCharacteristicUuid),
      history: requiredChar(goveeH5075HistoryCharacteristicUuid),
    );
  }

  void _ensureNotAborted() {
    if (_aborted) {
      throw const _GattProbeAborted();
    }
  }

  Future<void> _cleanupConnection() async {
    final subscriptions = List<StreamSubscription<List<int>>>.from(
      _subscriptions,
    );
    _subscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    final device = _activeDevice;
    _activeDevice = null;
    if (device != null && device.isConnected) {
      try {
        await device.disconnect();
      } on Object {
        // Disconnect cleanup must not hide the probe result.
      }
    }
  }

  void _emit(GoveeH5075GattProbeStatus status, String? message) {
    _status = status;
    _message = message;
    if (_disposed || _controller.isClosed) {
      return;
    }
    _controller.add(_snapshot());
  }

  GoveeH5075GattProbeSnapshot _snapshot({
    GoveeH5075GattProbeStatus? status,
    String? message,
  }) {
    return GoveeH5075GattProbeSnapshot(
      status: status ?? _status,
      message: message ?? _message,
      device: _request?.advertisement,
      historyWindow: _request?.historyWindow,
      historyChunk: _request?.historyChunk,
      currentMeasurement: _currentMeasurement,
      batteryPercent: _batteryPercent,
      services: _services,
      rawEvents: _rawEvents,
      historyRecords: _historyRecords,
      rawHistoryNotificationsOmitted: _rawHistoryNotificationsOmitted,
    );
  }
}

class _KnownCharacteristics {
  const _KnownCharacteristics({
    required this.device,
    required this.command,
    required this.history,
  });

  final BluetoothCharacteristic device;
  final BluetoothCharacteristic command;
  final BluetoothCharacteristic history;
}

class _GattProbeAborted {
  const _GattProbeAborted();
}
