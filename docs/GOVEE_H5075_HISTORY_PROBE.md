# Govee H5075 Read-only GATT History Probe

Status 2026-05-02: Pakete
`9.7-govee-h5075-thirty-day-experimental-probe` und
`9.8-govee-h5075-history-visualization`. Der Read-only-GATT-Probe und die
erste Govee-nahe Historienansicht wurden mit echter iPhone/H5075-Hardware
praktisch positiv getestet.

## Ziel

dewprofi hat jetzt einen experimentellen, explizit nutzergetriggerten
GATT-Probe-Pfad fuer H5075-Kandidaten. Der Flow verbindet sich nicht beim
Appstart und nicht beim normalen BLE-Scan. Er stoppt den Scan vor der Probe,
verbindet sich mit dem ausgewaehlten Kandidaten, inventarisiert Services,
aktiviert Notifications fuer bekannte Response-Characteristics, fragt aktuelle
Messung/Batterie ab und startet ein explizit gewaehltes History-Fenster.

Technisch sind die Requests BLE-Writes. Produktseitig sind sie read-only:
zugelassen sind nur CCCD-Notification-Aktivierung, aktuelle Messung,
Batterie-Gegenprobe und History-Read-Requests. Alarme, Offsets,
Kalibrierungen, Units und Konfiguration werden nicht geschrieben.

## Ground Truth fuer die erste Hardwareprobe

Nutzer-Screenshot aus der Govee-App fuer denselben oder vergleichbaren H5075:

- Geraet/Ort: `Veranda`
- Bluetooth verbunden
- Batterie: `83 %`
- Aktuelle Werte: `22.0 °C`, `29.5 % rF`
- Letzte Aktualisierung: `18:47`, `1. Mai`
- Wochenansicht: `18:46, 24. Apr.` bis `18:46, 1. Mai`
- Temperatur-Woche: Max `41.9 °C`, Avg `20.3 °C`, Min `10.6 °C`
- Feuchte-Woche: sichtbarer Max-Wert `53.6 %`

Diese Werte sind die konkrete Gegenprobe fuer die erste echte GATT-Session:

- `aa01` Current-Measurement sollte ungefaehr `22.0 °C`, `29.5 % rF` und
  `83 %` Batterie liefern.
- `aa08` Battery sollte ebenfalls `83 %` oder eine plausibel nahe Anzeige
  liefern.
- Das erste 10-Minuten-Fenster sollte Records um `18:37` bis `18:46/18:47`
  am 2026-05-01 liefern.
- Nach erfolgreichem 10-Minuten-Fenster ist 1 Stunde erlaubt, danach 24
  Stunden und danach 7 Tage. Die Woche aus dem Screenshot belegt, dass das
  Geraet bzw. die Govee-App mindestens eine Woche Verlauf sichtbar machen kann.
  Der 20-Tage-Abruf ist nur als bewusst experimenteller, bestaetigter Langtest
  gedacht.

## Implementierter App-Pfad

- Port/Modell: `lib/features/govee/govee_h5075_gatt_probe.dart`
- FlutterBluePlus-Adapter:
  `lib/features/govee/flutter_blue_plus_govee_h5075_gatt_probe.dart`
- UI: `Govee H5075 Spike` im Sensor-Modus, Button `GATT-Probe`
- History UI: Button `Historie` nach geladenen Records, full-screen
  Govee-nahe Ansicht mit blauem Header und Chartkarten
- Tests: `test/features/govee_h5075_gatt_probe_test.dart` und
  `test/features/humidity_calculator_page_test.dart`, ViewModel-Tests in
  `test/features/govee_h5075_history_view_model_test.dart`

Die UI bietet progressive Fenster bis 20 Tage sowie einen unbestaetigten
30-Tage-Experimental-Probe. 20 und 30 Tage sind sichtbar gewarnt und muessen
vor der Auswahl bestaetigt werden. Partial Downloads zeigen zusaetzlich den
aktiven Chunk, eindeutige Records, aeltesten/neuesten Record und einen
empfohlenen Folgechunk.

Geladene Records koennen direkt in der App geoeffnet werden. Die Historienseite
zeigt aktuelle Temperatur/Feuchte aus GATT-Current oder dem neuesten
History-Record, Tabs fuer `Stunde`, `Tag`, `Woche`, `Monat`, `Jahr`,
Temperatur- und Feuchte-Karten mit Max/Avg/Min, Zeitachse, Durchschnittslinie
und eine Coverage-Diagnose. Das ViewModel dedupliziert nach beobachteter Minute,
bucketed laengere Zeitraeume und markiert groessere Datenluecken, damit
unvollstaendige Downloads nicht als lueckenlose Kurve erscheinen.

| Stufe | Request | Timeout | Zweck |
| --- | --- | --- | --- |
| 10 min | `3301` start `10`, end `1` | 12 s | kleinster sicherer Datendurchlauf |
| 1 h | `3301` start `60`, end `1` | 20 s | Stabilitaet und Record-Reihenfolge pruefen |
| 24 h | `3301` start `1440`, end `1` | 45 s | groesserer Download ohne Vollspeicher-Risiko |
| 7 d | `3301` start `10080`, end `1` | 4 min | Wochenfenster gegen Govee-App-Wochenansicht pruefen |
| 20 d | `3301` start `28800`, end `1` | 15 min | experimenteller Full-Window-Probe mit Abbruchmoeglichkeit |
| 30 d | `3301` start `43200`, end `1` | 20 min | unbestaetigter 30-Tage-Probe fuer Hardware-Grenztest |

Der Protocol-Builder begrenzt History-Requests auf die experimentelle
Obergrenze `43200` Minuten. Der App-Flow verbindet nicht automatisch; die
langen Fenster sind nur ueber die manuelle Probe erreichbar. 20 und 30 Tage
sind keine Produktpfade und sollen nicht vor stabilen Hardwarelogs als
Verfuegbarkeit verkauft werden.

## Chunking und Resume

Der erste echte 20-Tage-Probe auf `GVH5075_47EE` hat belegt, dass der Request
`33 01 70 80 00 01 ... c3` echte History ab `-28800m` liefert, aber vor dem
neuesten Ende stoppte. Zwei beobachtete Runs lieferten etwa:

- `12645` Records, Range ca. `-28800m` bis `-15958m`
- `13606` Records, Range `-28800m` bis `-14997m`

Deshalb modelliert die App History nicht mehr nur als festes Fenster, sondern
als konkreten Chunk `start -> end`. Bei einem partial Range wie
`-28800m..-14997m` empfiehlt die Diagnose den naechsten manuellen Chunk
`14996 -> 1`. Dieser Folgechunk bleibt ein allowlisted `33 01`-History-Read auf
`...2012`; es gibt weiterhin keine automatische GATT-Verbindung und keine
Alarm-, Offset- oder Config-Writes.

Das Raw-GATT-Log ist weiterhin kopierbar und enthaelt `historyChunk`,
`historyRecords`, `historyRange`, `historyOldest`, `historyNewest` und bei
partial Downloads `nextHistoryChunk`.

## Hardwarevalidierung 2026-05-02

Der Nutzer hat den iPhone-Pfad mit `GVH5075_47EE` nach dem Chunking/Resume- und
Historienansicht-Stand praktisch positiv getestet.

Gesicherter letzter GATT-Lauf:

- Status: `completed`
- Geraet: `GVH5075_47EE`
- History-Fenster: `20 d`
- History-Chunk: `2306 -> 1`
- Records: `2114` eindeutige Records
- Range: `-2306m..-1m`
- Oldest: `2026-04-30T16:58:35`, `22.2 °C`, `16.0 %`
- Newest: `2026-05-02T07:23:35`, `12.4 °C`, `51.8 %`
- Batterie: `95 %`
- Write: `33 01 09 02 00 01 ... 38`, also allowlisted History-Read

Damit ist belegt, dass ein neu empfohlener Folgechunk bis zur neuesten Minute
funktioniert und die App geladene Records anschliessend darstellen kann. Der
Chunk ist zeitlich abgeschlossen, aber nicht lueckenlos: Bei `2306` Minuten
Range und `2114` eindeutigen Records fehlen in diesem Lauf ca. `192`
Minutenpunkte. Die Coverage-Anzeige der Historienansicht ist deshalb Teil des
Produktverhaltens und kein reines Debug-Detail.

## GATT UUIDs und Commands

Bekannter Custom Service:

- Service: `494e5445-4c4c-495f-524f-434b535f4857`
- Device/Config Characteristic: `494e5445-4c4c-495f-524f-434b535f2011`
- Command/Control Characteristic: `494e5445-4c4c-495f-524f-434b535f2012`
- History/Data Characteristic: `494e5445-4c4c-495f-524f-434b535f2013`

Allowlist im dewprofi-Spike:

| Zweck | Characteristic | Prefix | Payload |
| --- | --- | --- | --- |
| Current Measurement + Battery | `...2012` | `aa 01` | 20 Byte, XOR-Checksum |
| Battery Gegenprobe | `...2011` | `aa 08` | 20 Byte, XOR-Checksum |
| History-Fenster | `...2012` | `33 01` | start/end Minuten zurueck, 20 Byte, XOR-Checksum |

Nicht implementiert: `33 03`, `33 04`, `33 06`, `33 07` und andere Set-
Kommandos fuer Alarme, Offsets oder Kalibrierung. Read-Kommandos fuer Hardware
oder Firmware koennen spaeter als eigene Allowlist ergaenzt werden, falls die
erste Probe stabil ist.

## Parser-Stand

Gesichert und implementiert:

- Current response `aa 01`: Temperatur und Feuchte als Big-Endian 16-bit
  Werte in Hundertstel-Einheiten, Batterie als Prozentbyte.
- Battery response `aa 08`: Batterie als Prozentbyte.
- History notification `...2013`: Byte 1-2 sind Minuten zurueck fuer den
  ersten Record, danach bis zu sechs 3-Byte-Records. Jeder Record nutzt die
  belegte H5075-Packing-Formel:
  - Temperatur: `int(encoded / 1000) / 10`
  - Feuchte: `encoded % 1000 / 10`
  - gesetztes `0x800000`-Bit markiert negative Temperatur.

Unbekannte oder unplausible Responses werden im Raw-GATT-Log behalten. Parser
erfinden keine Firmwarevariante.

## Nutzer-Testscript fuer die naechste echte Probe

1. Govee-App schliessen oder mindestens nicht aktiv synchronisieren lassen.
2. H5075 `Veranda` nahe ans iPhone legen; Bluetooth einschalten.
3. App per `flutter run -d <iphone-id>` starten.
4. Eingabe ausklappen, `Sensor` waehlen, `Scannen` tippen.
5. Warten, bis `GVH5075_47EE` oder ein passender Kandidat sichtbar ist.
6. Raw Advertisement kopieren und mit LCD/App-Werten notieren.
7. History-Fenster auf `10 min` lassen.
8. Beim Kandidaten `GATT-Probe` tippen.
9. Nach Abschluss `Raw GATT Log` kopieren.
10. Werte gegen Ground Truth pruefen: etwa `22.0 °C`, `29.5 % rF`, `83 %`.
11. Falls 10 Minuten stabil sind: auf `1 h` stellen und erneut starten.
12. Falls 1 Stunde stabil ist: auf `24 h` stellen und erneut starten.
13. Falls 24 Stunden stabil sind: auf `7 d` stellen und erneut starten.
14. 7-Tage-Ergebnis gegen die Govee-App-Wochenansicht vergleichen:
    - Zeitraum ca. `18:46, 24. Apr.` bis `18:46, 1. Mai`
    - Temperatur grob: Max `41.9 °C`, Avg `20.3 °C`, Min `10.6 °C`
    - Feuchte: sichtbarer Max-Wert `53.6 %`
15. Nur wenn 7 Tage stabil sind und der Nutzer den Langtest bewusst will:
    `20 d` waehlen, Dialog `20 Tage aktivieren` bestaetigen und waehrend des
    Abrufs abbrechbereit bleiben.
16. Wenn der 20-Tage-Abruf partial endet, `Raw GATT Log` sichern. Zeigt das Log
    z. B. `nextHistoryChunk: 14996 -> 1`, kann der UI-Button `Folgechunk`
    manuell genau diesen neueren Bereich anfragen.
17. Wenn die 20-Tage-Kette stabil bis `-1m` belegbar ist und der Grenztest
    bewusst gewollt ist: `30 d` waehlen, Dialog `30 Tage aktivieren`
    bestaetigen und Raw Log sichern. Erwarteter Request:
    `33 01 a8 c0 00 01 ... 5b`.
18. Bei Timeout, vielen unbekannten Responses oder instabiler Verbindung:
    abbrechen, Raw Log sichern, keine groessere Stufe starten.

Pro Durchlauf bitte zusaetzlich notieren:

- iPhone-Modell, iOS-Version, App-Startzeit mit Zeitzone.
- H5075-Name, Plattform-ID, RSSI und ungefaehre Entfernung.
- Ob die Govee-App parallel offen war.
- LCD-Werte direkt vor und direkt nach der Probe.
- Ob der Bluetooth-Icon am H5075 sichtbar war.

## Risiken und Grenzen

- Echte iOS-GATT-Sessions mit H5075-Hardware sind positiv belegt. Der
  monolithische 20-Tage-Request lieferte echte alte History, stoppte aber
  partial; manuelle Folgechunks konnten den neueren Bereich bis `-1m` laden.
- 30 Tage ist unbestaetigt. Das Geraet kann den Request ablehnen, leer
  beantworten oder wieder nur einen juengeren/partial Range liefern.
- FlutterBluePlus-GATT auf macOS bleibt per Default deaktiviert:
  `DEWPROFI_ENABLE_MACOS_FBP_GATT_PROBE=true` waere nur fuer gezielte Proben.
- Die Govee-App kann eine laufende Verbindung kurz blockieren oder selbst
  blockiert werden.
- History-Zeitstempel sind relativ zum Downloadstart rekonstruiert; eine
  belegte absolute Uhrzeit-Characteristic wird nicht vorausgesetzt.
- Full-History bis ca. 20 Tage ist technisch als manueller Experimental-Probe
  vorbereitet und per Chunk/Resume praktisch positiv angelaufen. Wegen
  beobachteter Datenluecken bleibt es noch kein Produktversprechen fuer
  lueckenlose 20 Tage.

## Quellen

- Heckie75 API notes:
  https://raw.githubusercontent.com/Heckie75/govee-h5075-thermo-hygrometer/main/API.md
- Heckie75 Python/Bleak implementation:
  https://github.com/Heckie75/govee-h5075-thermo-hygrometer/blob/main/govee-h5075.py
- wcbonner/GoveeBTTempLogger:
  https://github.com/wcbonner/GoveeBTTempLogger
- wcbonner H5075 download code:
  https://github.com/wcbonner/GoveeBTTempLogger/blob/master/goveebttemplogger.cpp
- Bluetooth-Devices/govee-ble parser:
  https://github.com/Bluetooth-Devices/govee-ble/blob/main/src/govee_ble/parser.py
- asednev/govee-bt-client advertisement decoder:
  https://github.com/asednev/govee-bt-client
- Theengs H5075 decoder:
  https://decoder.theengs.io/devices/H5075.html
