# Govee H5075 Capability Research and Probe Plan

Status 2026-05-01: Research-/Probe-Plan fuer Paket
`9.3-govee-h5075-capability-research-and-probe-plan`.

Update 2026-05-01 fuer Paket
`9.4-govee-h5075-readonly-gatt-history-probe-spike`: Der erste
nutzergetriggerte App-Probe-Pfad ist vorbereitet. Details, Ground Truth aus
der Govee-App und das konkrete Hardware-Testscript stehen in
`docs/GOVEE_H5075_HISTORY_PROBE.md`.

Update 2026-05-01 fuer Paket
`9.5-govee-h5075-seven-and-twenty-day-history-probe`: Der App-Probe-Pfad
enthaelt jetzt die Fenster 7 Tage und 20 Tage. 20 Tage ist nur nach
ausdruecklicher UI-Bestaetigung und sichtbarer Warnung erreichbar.

## Ziel

Dieser Plan klaert, welche Daten beim Govee H5075 realistisch lokal auslesbar
sind, und legt eine vorsichtige Try-and-Error-Matrix fuer dewprofi fest. Die
Matrix trennt passive Advertisement-Proben von aktiven GATT-Proben. Automatische
GATT-Verbindungen bleiben ausserhalb dieses Pakets.

## Quellenlage

### Gesichert

- Passive H5075-Advertisements enthalten aktuelle Temperatur, relative Feuchte
  und Batterie im Govee-Manufacturer-Layout mit Company-ID `0xEC88` bzw. Byte-
  Reihenfolge `88 EC`; belegt durch Thrilleratplay/GoveeWatcher,
  Heckie75/govee-h5075-thermo-hygrometer, Theengs und dewprofi-Hardwaretests.
- Das passive Layout nutzt ein Padding-Byte, einen 24-Bit Temperatur/Feuchte-
  Wert und danach ein Batteriebyte. Die bekannte Dekodierung ist:
  Temperatur als `int(encoded / 1000) / 10`, Feuchte als
  `encoded % 1000 / 10`, Batterie als Prozentbyte, sofern plausibel.
- Der H5075 sendet GATT-Dienste unter dem Govee/IntelliRocks-Service
  `494e5445-4c4c-495f-524f-434b535f4857` mit Charakteristiken `...2011`,
  `...2012` und `...2013`. Community-Tools nutzen diese fuer Kommandos,
  aktuelle Messwerte und History-Download.
- Aktiv per GATT belegte Daten: Device Name, MAC/Adresse auf Plattformen, die
  sie freigeben oder per GATT-Kommando liefern, Hardware-Version, Firmware-
  Version, aktuelle Temperatur/Feuchte/Batterie, Temperatur-/Feuchte-Alarme,
  Temperatur-/Feuchte-Offsets und historische Messwerte.
- Home Assistant listet H5075 in der Govee-Bluetooth-Integration und markiert
  ihn als Geraet, fuer das aktive Scans noetig sein koennen. Theengs markiert
  H5075 als unverschluesselte BLE-Broadcast-Quelle fuer Temperatur, Feuchte und
  Batterie.
- iOS/CoreBluetooth liefert keinen echten BLE-MAC als stabile App-ID. dewprofi
  muss Device-Name, Plattform-ID und Rohpayload trennen.

### Wahrscheinlich

- Der H5075 speichert ungefaehr 20 Tage History mit etwa einminuetiger
  Aufloesung. Heckie75 dokumentiert maximal 20 Tage, wcbonner zeigt fuer zwei
  H5075 etwa `28800` bis `28803` heruntergeladene Minutenpunkte. dewprofi-
  Hardwaretests bestaetigen echte alte History ab `-28800m`; neuere Bereiche
  muessen bei diesem Geraet teilweise per Folgechunk bis `-1m` geladen werden.
- History-Zeitstempel werden beim Download aus relativen Minuten rekonstruiert,
  nicht aus einer belegten absoluten Uhrzeit-Characteristic. Eine Uhrzeit- oder
  Sync-Status-Abfrage sollte deshalb nicht vorausgesetzt werden.
- Die GATT-Batterieantwort ist verlaesslicher als das passive Batteriebyte,
  wenn Advertisements wie das dewprofi-macOS-Sample `0x00` liefern. `0x00` kann
  leer, unbekannt, ein Plattform-/Payload-Artefakt oder eine Firmware-Variante
  sein und bleibt ohne Gegenprobe unvalidiert.
- Alarme und Kalibrierungs-Offsets sind aktiv les- und setzbar. Fuer dewprofi
  ist zunaechst nur Lesen sinnvoll; Schreiben sollte erst nach separater
  Sicherheitsentscheidung erfolgen.
- Service UUID `EC88` ist ein wichtiger Discovery-Hinweis. Es gibt aber keine
  starke Quelle, dass H5075-Livewerte separat in BLE Service Data statt in
  Manufacturer Data uebertragen werden.

### Unklar / Spekulativ

- Units-Flags, LCD-Einheiten, Alarmstatus im passiven Advertisement und
  Sampling-Intervalle als konfigurierbare Werte sind fuer H5075 nicht sicher
  belegt.
- Firmware-Unterschiede koennen Payload-Laenge, Batteriebyte und
  Connectability/Scan-Response beeinflussen. dewprofi darf nur bekannte,
  plausible Payloads dekodieren und muss unbekannte Varianten als Raw-Sample
  behalten.
- iOS-Hintergrundscan, langfristige Live-Sammlung auf iOS und parallele Nutzung
  der Govee-App sind nicht gesichert. Fuer Produktbetrieb ist ein Android-,
  Raspberry-Pi-, Desktop- oder ESPHome/Home-Assistant-Collector
  wahrscheinlich robuster.

## Datenkategorien

### Passiv per BLE Advertisement

- Aktuelle Temperatur in Celsius: gesichert fuer bekannte Manufacturer-Payloads.
- Relative Feuchte: gesichert fuer bekannte Manufacturer-Payloads.
- Batterie: gesichert als normales Prozentbyte in vielen Samples, aber
  Variante `0x00` bleibt in dewprofi bewusst `unknown`.
- Device-Name: meist `GVH5075_....`, aber plattformabhaengig.
- Device-ID: auf Linux/Android oft MAC-naeher, auf iOS/macOS eine
  CoreBluetooth-ID; nicht als globale Geraeteidentitaet behandeln.
- RSSI: vom Scanner, nicht aus dem H5075-Nutzdatenpayload.
- Raw Manufacturer Data, Service UUIDs, Connectable-Flag, TX Power/Appearance
  soweit die Plattform sie freigibt.
- Flags/Alarm/Units: nicht belegt; nur als Raw beobachten.

### Aktiv per BLE/GATT

- Generic Access: Device Name, Appearance, Preferred Connection Parameters
  koennen je nach Plattform sichtbar sein.
- Device Information: PnP ID ist in wcbonner-Samples sichtbar; Hersteller,
  Modell, Hardware und Firmware werden bei Heckie75 vor allem ueber
  Govee-Kommandos dokumentiert.
- Custom Service `494e5445-4c4c-495f-524f-434b535f4857`:
  - `...2011`: Konfiguration/Device-Daten-Kommandos, u.a. Alarme, Offsets,
    MAC, Hardware- und Firmware-Version.
  - `...2012`: Kommando-/Control-Pfad, u.a. aktuelle Messung/Batterie und
    History-Request.
  - `...2013`: History-Daten-Notifications.
- History: Temperatur/Feuchte-Punkte als 3-Byte-Datensaetze, offenbar relativ
  zu Minuten vor dem Downloadzeitpunkt.
- Zugriff auf die History ist lokal und technisch moeglich, aber nur aktiv:
  dewprofi sollte dafuer einen expliziten Button/Flow verwenden, ein kleines
  Fenster lesen, die Rohantworten speichern und danach sofort trennen.
- Schreiben von Alarmschwellen/Offsets ist belegt, bleibt fuer dewprofi aber
  out of scope, bis ein separater Write-Sicherheitsplan existiert.

## Plattformgrenzen fuer dewprofi

- iOS: passive Foreground-Scans sind durch 9.2 mit echter Hardware belegt.
  Device-ID ist nicht der echte MAC. Hintergrund-Scanning und dauerhafte
  Collector-Funktion nicht voraussetzen.
- macOS: ein minimales CoreBluetooth-Bundle konnte passiv scannen; der
  FlutterBluePlus-Darwin-Pfad ist in dewprofi per Default gegated, weil der
  TCC-Pfad crashte. macOS-Proben daher entweder mit Feature-Flag oder besser
  mit isolierter CoreBluetooth-/Python-bleak-Probe.
- Android: Manifest ist vorbereitet, aber lokal noch nicht validiert, weil die
  Android-SDK-Installation deferred ist.
- Linux/Raspberry Pi: staerkste Community-Erfahrungen fuer passive Scanner,
  bleak, BlueZ, noble, Home Assistant und Theengs. Gut als externes
  Referenzwerkzeug, aber nicht Voraussetzung fuer die iOS-App.
- ESPHome/OpenMQTTGateway/Theengs: gute Referenz fuer passive BLE-Gateways und
  Home-Assistant-Nutzung, aber kein direkter Beleg fuer H5075-GATT-History.

## Experimentmatrix

### Passive Advertisement-Probes

| ID | Ziel | Hypothese | Schritt | Erwarteter Output | Erfolgskriterium | Risiko | Rollback / Fallback |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P1 | iPhone-Rawpayload sichern | iOS liefert Manufacturer Data fuer `GVH5075_47EE` stabil genug | `flutter run -d <iphone-id>`, Sensor-Scan, Raw Sample kopieren | Device-Name, iOS-ID, RSSI, `manufacturer 0xEC88: ...`, Service UUIDs | Raw Sample passt zu LCD-Temperatur, LCD-Feuchte und Govee-App-Batterie | iOS zeigt einzelne Pakete nicht oder kuerzt Daten | Mehrfach scannen, H5075 naeher ans iPhone, Govee-App schliessen |
| P2 | Batteriebyte `0x00` validieren | `0x00` im macOS-Sample ist kein echter 0-Prozent-Stand | Parallel LCD/App-Batterie notieren und erneut Raw Samples sammeln | Mehrere Raw Samples mit Batteriebyte und App-Batterie | `0x00` kann als unknown bestaetigt oder durch neues Prozentbyte ersetzt werden | Falscher Schluss bei alter Batterieanzeige | Batterie nie aus `0x00` ableiten; GATT-Batterieprobe G2 priorisieren |
| P3 | Payload-Varianten sammeln | Firmware-/Hardware-Versionen koennen andere Laengen zeigen | iOS-Scan plus optional Theengs Explorer oder bleak-Scan auf macOS/Linux | Raw Manufacturer, Service UUIDs, RSSI, Name, Plattform | Unbekannte Payloads bleiben Raw und crashen Parser nicht | Tool zeigt Daten anders sortiert | Rohbytes immer mit Plattform/Tool notieren |
| P4 | RSSI-/Stabilitaetsfenster bestimmen | `-80 dBm` ist fuer UI-Probe konservativ brauchbar | H5075 bei 0.5 m, 2 m, 5 m scannen, sichtbare Counts notieren | sichtbare/gesamte Advertisements je Distanz | Default-Threshold bleibt plausibel oder wird begruendet angepasst | Umgebung/Interferenz verfalscht Ergebnis | Threshold in UI manuell variieren; kein Produktversprechen |
| P5 | Service Data ausschliessen/einordnen | Livewerte liegen beim H5075 in Manufacturer Data, nicht Service Data | Raw Samples gezielt auf `serviceData` pruefen | Service UUID `EC88`; meist keine separate Service Data | dewprofi nutzt Service UUID nur fuer Discovery, nicht fuer Werte | einzelne Plattformen mappen Felder anders | Parser bleibt Manufacturer-first; Service Data nur loggen |
| P6 | Temperaturformel gegen LCD pruefen | Zehntelgrad-Formel passt LCD/App besser als `raw / 10000` | Raw Sample, LCD-Temperatur und Govee-App-Wert zeitgleich notieren | dekodierte Temperatur mit einer Nachkommastelle | Anzeige passt ueber mehrere Samples, auch bei wechselnder Feuchte | LCD/App runden und reagieren traeger | GATT-Current-Measurement G2 als Referenzwert verwenden |

### Aktive GATT-Probes

| ID | Ziel | Hypothese | Schritt | Erwarteter Output | Erfolgskriterium | Risiko | Rollback / Fallback |
| --- | --- | --- | --- | --- | --- | --- | --- |
| G1 | Services ohne Writes inventarisieren | H5075 exponiert den IntelliRocks-Service und bekannte Charakteristiken | Nur Nutzeraktion: externe Probe mit `bleak`/nRF Connect; connect, discover services, disconnect | Service `...4857`, Chars `...2011`, `...2012`, `...2013`, ggf. Generic Access/Device Info | UUIDs und Properties stimmen mit Quellen ueberein | Connection kann Govee-App kurz blockieren | Disconnect, Govee-App neu oeffnen, keine Writes ausfuehren |
| G2 | Aktuelle Messung/Batterie lesen | GATT-Kommando `aa 01 ...` auf `...2012` liefert Temp/Feuchte/Batterie | Nur isolierter Spike/Script, Notifications aktivieren, Kommando schreiben, Antwort loggen | Antwort mit Temperatur, Feuchte, Batterie | Werte matchen LCD/App innerhalb realistischer Rundung | Write-Kommando trotz Read-Ziel; Batteriebelastung minimal | Nur ein Versuch, dann disconnect; bei Fehler keine Wiederholschleife |
| G3 | Firmware/Hardware lesen | Kommandos auf `...2011` liefern ASCII-Versionen | Notifications auf `...2011`, bekannte Version-Kommandos einzeln senden | Hardware z.B. `1.03.02`, Firmware z.B. `1.04.06` | Versionen werden eindeutig geloggt | Firmware antwortet anders oder gar nicht | Raw Antwort speichern, keine Parserannahme |
| G4 | Offsets/Alarme read-only lesen | App-Kalibrierung und Alarmgrenzen sind lesbar | Nur Read-Kommandos fuer Humidity/Temperature Alarm und Offset; keine Set-Kommandos | Active-Flag, Grenzwerte, Offsets | Werte matchen Govee-App-Einstellungen | Verwechslung mit Set-Kommandos | Kommandos in Script als allowlist markieren; Schreibkommandos sperren |
| G5 | Kleine History lesen | History kommt ueber `...2013` in 3-Byte Records | History-Request fuer 10 Minuten, Notifications loggen, danach disconnect | 10 bis 11 Minutenpunkte, relative Minuten, Temperatur/Feuchte | Download laesst sich mit Govee-App/LCD plausibilisieren | Mehr Batterie, lang laufende Verbindung, Datenflut | Start mit 10 Minuten; Timeout; keine 20-Tage-Abfrage zuerst |
| G6 | Wochen- und voller History-Rahmen nur nach G5 | H5075 haelt mindestens die Govee-App-Woche und ca. 20 Tage/28800 Minutenpunkte | Manuell gestarteter Langtest: 10m -> 1h -> 24h -> 7d -> bestaetigter 20d-Probe | Anzahl Punkte, erste/letzte Records und Zeitspanne | 7d matcht Govee-App-Wochenansicht; 20d belegt nur den experimentellen Rahmen dieses Geraets | Lange Verbindung, Abbruch, Akku | Abbruch tolerieren; Raw Log sichern; keine Produktfreigabe ohne stabile kleinere Fenster |
| G7 | iOS-GATT-Spike bewerten | iOS kann Nutzer-initiierte GATT-Verbindung, aber nicht zwingend stabil als Collector | Erst nach externem Erfolg: isolierter Port/Feature-Flag, Button "Verbinden" | Services oder GATT-Fehler im UI-State | Keine automatische Verbindung, Fehler sauber sichtbar | App-Store-/Permission-/Background-Grenzen | Feature-Flag aus; passiver Pfad bleibt produktiv |
| G8 | macOS-GATT nicht ueber FBP erzwingen | FlutterBluePlus-macOS bleibt TCC-riskant | Externe bleak/CoreBluetooth-Probe statt App-Automatik | Services/Notifications ausserhalb Flutter | macOS-Erkenntnisse ohne App-Crash | TCC-Prompt/Crash im Tool | TCC-Berechtigung entfernen, Tool beenden, App-Guard bleibt |

## Nutzer-Notizen fuer jede Probe

Bitte pro Durchlauf notieren:

- Datum/Uhrzeit mit Zeitzone.
- iOS-/macOS-/Android-/Linux-Version und Tool/App-Version.
- H5075 Device-Name, z.B. `GVH5075_47EE`.
- Plattform-Device-ID und, falls Linux/Android sichtbar, MAC-Adresse.
- Raw Sample komplett: Manufacturer Data, Service Data, Service UUIDs,
  Connectable, TX Power, Appearance.
- RSSI und ungefaehre Entfernung zum Scanner.
- LCD-Temperatur und LCD-Feuchte zum gleichen Zeitpunkt.
- Govee-App-Temperatur, Feuchte, Batterie, Hardware/Firmware, Offsets und
  Alarmgrenzen, falls sichtbar.
- Ob die Govee-App parallel offen war oder vorher geschlossen wurde.
- Bei GATT: alle Service-/Characteristic-UUIDs, Properties, gesendetes Kommando,
  Antwortbytes, Timeout/Fehler und Disconnect-Zeitpunkt.

## Entscheidungen fuer dewprofi

- Passive Livewerte bleiben der Produktpfad fuer den naechsten Schritt.
- Batterie `0x00` bleibt `unknown`, bis LCD/App oder GATT sie bestaetigen.
- GATT wird nur hinter expliziter Nutzeraktion vorbereitet. In 9.4 existiert
  dafuer ein fakebarer `GoveeH5075GattProbe`-Port plus FlutterBluePlus-
  Adapter; macOS-GATT bleibt per Default gegated.
- Die erste GATT-App-Probe nutzt nur eine Allowlist: Notifications aktivieren,
  aktuelle Messung/Batterie, Batterie-Gegenprobe und History-Fenster 10 min,
  1 h, 24 h, 7 Tage, bestaetigte 20 Tage oder den bestaetigungspflichtigen
  30-Tage-Grenztest.
- Schreibende GATT-Kommandos fuer Offsets/Alarme sind trotz Community-Belegen
  vorerst tabu.
- Unbekannte Payloads werden gesammelt und dokumentiert, nicht geraten.
- Der Full-/20-Tage-Abruf ist ein manueller Experimental-Probe. Echte
  Hardwarelogs belegen Chunk/Resume bis `-1m`; wegen beobachteter Luecken bleibt
  er noch kein Produktpfad fuer lueckenlose 20 Tage.

## Wichtige Quellen

- Heckie75/govee-h5075-thermo-hygrometer:
  https://github.com/Heckie75/govee-h5075-thermo-hygrometer
- Heckie75 API notes:
  https://raw.githubusercontent.com/Heckie75/govee-h5075-thermo-hygrometer/main/API.md
- wcbonner/GoveeBTTempLogger:
  https://github.com/wcbonner/GoveeBTTempLogger
- Thrilleratplay/GoveeWatcher:
  https://github.com/Thrilleratplay/GoveeWatcher
- Theengs H5075 decoder page:
  https://decoder.theengs.io/devices/H5075.html
- Theengs Decoder project:
  https://github.com/theengs/decoder
- Theengs Gateway / OpenMQTTGateway ecosystem:
  https://github.com/theengs/gateway
- Home Assistant Govee Bluetooth:
  https://www.home-assistant.io/integrations/govee_ble/
- Home Assistant Govee BLE manifest:
  https://raw.githubusercontent.com/home-assistant/core/dev/homeassistant/components/govee_ble/manifest.json
- ESPHome Bluetooth Proxy docs:
  https://esphome.io/components/bluetooth_proxy/
- asednev/govee-bt-client Node/noble implementation:
  https://github.com/asednev/govee-bt-client
- Bluetooth-Devices/govee-ble Python package:
  https://github.com/Bluetooth-Devices/govee-ble
- Qiita bleak/H5075 experience:
  https://qiita.com/hiratarich/items/3f7991d4164e5f0ecc62
- Apple Core Bluetooth overview:
  https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothOverview/CoreBluetoothOverview.html
- Apple Core Bluetooth documentation:
  https://developer.apple.com/documentation/corebluetooth
