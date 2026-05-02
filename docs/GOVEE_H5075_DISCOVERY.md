# Govee H5075 Discovery Spike

Status 2026-05-01: Discovery-Spike implementiert; erster echter macOS-Advertisement-Capture fuer `GVH5075_ACC0` liegt vor. Der iPhone-Scanpfad ist mit echter H5075-Hardware validiert: `GVH5075_47EE` wurde bei `-41 dBm` dekodiert und in der App als `22,0 °C`, `29,1 % rF` und `95 %` Batterie angezeigt. Der FlutterBluePlus-macOS-Scan ist im App-Adapter vorerst per Default deaktiviert, weil der native Darwin-Pfad beim ersten Scan trotz vorhandener Bundle-Keys in TCC crashte. Der Research- und Try-and-Error-Plan fuer weitere passive und aktive Proben steht in `docs/GOVEE_H5075_PROBE_PLAN.md`; der vorbereitete 9.4-GATT-History-Probe steht in `docs/GOVEE_H5075_HISTORY_PROBE.md`.

## Ziel

Der Spike bereitet den lokalen BLE-Pfad fuer Govee H5075 vor:

- BLE-Scan ueber `flutter_blue_plus`
- einstellbares Mindestsignal, standardmaessig `-80 dBm`, vor Kandidaten-/Parser-Anzeige
- H5075-Kandidaten ueber Name oder Govee-Manufacturer-Daten erkennen
- Raw-Advertisement-Samples in der App sichtbar und kopierbar machen
- bekannte passive H5075-Manufacturer-Payloads in Temperatur, relative Feuchte und Batterie dekodieren
- dekodierte Live-Werte in denselben Feuchte-Ergebnispfad uebernehmen

Nicht enthalten: GATT-Verbindung, History-Sync, Govee-Account, Cloud/OpenAPI.

Update 9.4: GATT bleibt vom normalen Scan getrennt. Der neue History-Probe ist
ein separater Button im Sensor-Spike und nutzt die im Nutzer-Screenshot
gesicherten Govee-App-Werte als erste Gegenprobe: `Veranda`, `22,0 °C`,
`29,5 % rF`, `83 %` Batterie und mindestens eine sichtbare Woche History vom
24. Apr. 18:46 bis 1. Mai 18:46.

## Implementierter Schnitt

- Scanner-Port: `lib/features/sensors/ble_advertisement_scanner.dart`
- FlutterBluePlus-Adapter: `lib/features/sensors/flutter_blue_plus_ble_scanner.dart`
- Raw-Modell: `lib/core/sensors/ble_advertisement.dart`
- Normalisierte Live-Messung: `lib/core/sensors/sensor_measurement.dart`
- H5075-Parser: `lib/features/govee/govee_h5075_parser.dart`
- Spike-UI: Datenquelle `Sensor` im Rechner

Der Parser dekodiert nur das bekannte Govee-Manufacturer-Layout mit Company-ID `0xEC88`, einem Padding-Byte, 24-Bit Temperatur/Feuchte-Wert und Batteriebyte. FlutterBluePlus entfernt die zwei Company-ID-Bytes bereits aus der Manufacturer-Payload; auf Darwin wird aus dem Raw-Wert `88 EC 00 02 92 76 00 00` also die Parser-Payload `00 02 92 76 00 00`. Seit Paket 9.3 folgt die Temperaturdekodierung der durch Heckie75/wcbonner/Theengs belegten Zehntelgrad-Formel `int(encoded / 1000) / 10`; die Feuchte bleibt `encoded % 1000 / 10`. Unplausible oder unbekannte Payloads bleiben Raw-Debug-Samples; es werden keine Firmware-Details erfunden.

Der RSSI-Filter sitzt bewusst vor Discovery, Parser und Raw-Sample-Anzeige. Der
Scanner sammelt weiterhin Advertisements, aber die Spike-UI zeigt nur Samples ab
dem eingestellten Mindestsignal. Der erste echte H5075-Capture lag bei `-70 dBm`,
daher startet der Spike konservativ bei `-80 dBm`.

## iPhone-Hardwarevalidierung

iPhone-App-Scan am 2026-05-01:

```text
name: GVH5075_47EE
rssi: -41
decoded temperature: 22,0 °C
decoded relative humidity: 29,1 %
decoded battery: 95 %
visible advertisements: 8/30 above -80 dBm
```

Damit ist bestaetigt, dass der iOS-Pfad passive H5075-Advertisements sichtbar
macht, der Parser Livewerte dekodiert und die Spike-UI den Sensorwert in den
Feuchte-Ergebnispfad uebernehmen kann. Das passende Raw-Sample sollte bei der
naechsten Debug-Runde noch kopiert werden, damit die iPhone-Payload als
Regressionstest neben dem macOS-Capture abgelegt werden kann.

## Erster macOS-Capture

macOS-Scan am 2026-05-01:

```text
name: GVH5075_ACC0
id: E1C8662B-38E7-519A-E0CC-07531BC1E78C
rssi: -70
manufacturer: 88 EC 00 02 92 76 00 00
services: EC88
```

Parser-Ergebnis fuer die von FlutterBluePlus getrimmte Payload `00 02 92 76 00 00` nach 9.3:

- Temperatur: 16,8 °C
- Relative Feuchte: 56,6 %
- Batteriebyte: `0x00`, aktuell als unbekannt behandelt

Das Batteriebyte wird nur fuer Werte `1..100` als Prozentwert uebernommen. Byte
`0x00` aus dem ersten echten Sample wird nicht mehr als `0 %` angezeigt, weil
das ohne Gegenpruefung gegen LCD oder Govee-App zu wahrscheinlich eine
Fehlannahme waere. Beim naechsten manuellen Check sollte der sichtbare
Batteriestatus am Geraet oder in der Govee-App gegengeprueft werden.

## iPhone-Testscript fuer weitere Samples

1. iPhone entsperren, Bluetooth einschalten, H5075 in Reichweite legen.
2. App per `flutter run -d <iphone-id>` starten.
3. In der App die Eingabe ausklappen und `Sensor` waehlen.
4. `Scannen` tippen.
5. iOS-Bluetooth-Dialog erlauben.
6. Erwartung: `GVH5075...`, `H5075...` oder ein Govee-Kandidat erscheint. Raw Samples zeigen Manufacturer- oder Service-Daten.
7. Falls ein Wert dekodiert wird: `Wert uebernehmen` tippen und Temperatur/Feuchte im Ergebnis pruefen.
8. Falls kein Wert dekodiert wird: Raw Sample kopieren und mit Geraet/Firmware/angezeigtem LCD-Wert notieren.

Zu erfassen, wenn neue Firmware-/Geraetevarianten auftauchen:

- Device-Name und Device-ID aus der App
- kompletter Raw-Sample-Text
- sichtbare LCD-Werte am H5075 zum gleichen Zeitpunkt
- iOS-Version und ob Manufacturer-Daten sichtbar waren

## macOS-Testscript

1. Bluetooth einschalten und H5075 in Reichweite legen.
2. `flutter run -d macos`
3. In `Sensor` scannen.
4. Erwartung im Default-Build: Die App bleibt stabil und zeigt, dass der
   macOS-Scan im FlutterBluePlus-Adapter deaktiviert ist.
5. Nur fuer gezielte Plugin-Probe: mit
   `flutter run -d macos --dart-define=DEWPROFI_ENABLE_MACOS_FBP_BLE_SCAN=true`
   starten, in `Sensor` scannen und macOS-Bluetooth-Berechtigung erlauben.
6. Raw Samples kopieren, falls der Plugin-Pfad nicht crasht.

Hinweis: Fuer macOS sind `NSBluetoothAlwaysUsageDescription`,
`NSBluetoothPeripheralUsageDescription` und
`com.apple.security.device.bluetooth` gesetzt. Der erste Flutter-macOS-Scan ist
trotzdem in TCC gecrasht, obwohl das gebaute App-Bundle die Keys enthielt. Ein
separates minimales CoreBluetooth-App-Bundle konnte nach Bluetooth-Freigabe
scannen und das Sample oben erfassen. Das spricht fuer ein macOS-/Plugin-Bundle-
Kontextproblem im FlutterBluePlus-Darwin-Pfad, nicht gegen die passive
H5075-Advertisement-Sichtbarkeit auf macOS. Der Default-Guard sitzt vor
`FlutterBluePlus.isSupported`, weil bereits die Darwin-Adapter-Initialisierung
einen `CBCentralManager` anlegt und damit den TCC-Pfad betritt. Wenn macOS in
der Produktlinie wichtig bleibt, ist der naechste technische Schritt eine kleine
native CoreBluetooth-Bridge oder ein isolierter Adapter hinter demselben
`BleAdvertisementScanner`-Port; ein kompletter App-Umbau ist dafuer nicht
noetig.

## Erwartete Grenzen

iOS kann BLE-Metadaten anders darstellen als Android/Linux, insbesondere Device-IDs und je nach Advertisement-Form sichtbare Payloads. Der Spike ist deshalb erst abgeschlossen, wenn echte H5075-Samples auf mindestens iPhone oder macOS bestaetigen, dass die passive Payload sichtbar ist. Android bleibt vorbereitet, aber lokal ohne Android SDK/cmdline-tools nicht validiert.
