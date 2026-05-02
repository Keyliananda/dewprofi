# dewprofi Roadmap

## 0. Zielbild

dewprofi wird zuerst ein visueller Feuchte-Rechner fuer Android und iOS. Das erste MVP endet bei einer funktionierenden grafischen Darstellung auf Basis von Standort-, Orts- oder manuellen Eingaben.

Bluetooth, Notifications, Account und Synchronisierung sind wichtige Produktlinien, kommen aber erst nach dem ersten MVP. Dadurch bleibt die erste Roadmap fokussiert auf den Kernnutzen: Werte eingeben oder laden, psychrometrisch berechnen, anschaulich darstellen.

## 1. Grundlagen klaeren

### 1.1 Fachliche Definitionen festlegen

Status 2026-05-01: Erledigt fuer den manuellen MVP-Schnitt. `lib/core/psychrometrics` berechnet Taupunkt, absolute Feuchte und nutzt 1013,25 hPa als Default-Luftdruck.

Ziel: Ein gemeinsames Rechenmodell fuer Temperatur, relative Luftfeuchte, Taupunkt, absolute Feuchte und optionalen Luftdruck.

Ergebnisse:

- Primaere Anzeigeeinheit: relative Luftfeuchte in Prozent
- Sekundaere Anzeige: Taupunkt
- Optionale Detailanzeige: absolute Feuchte in g/m3
- Standard-Luftdruck: 1013,25 hPa
- Rechenlogik lokal in der App, nicht vom Wetterdienst abhaengig

Akzeptanzkriterien:

- Fuer Temperatur und relative Luftfeuchte kann die App Taupunkt und absolute Feuchte berechnen.
- Ohne Druckeingabe wird ein plausibler Standardwert genutzt.
- Die Berechnungen sind als eigener App-Service oder eigenes Domain-Modul gekapselt.

### 1.2 Wetterdatenstrategie festlegen

Status 2026-05-01: Erledigt fuer den ersten Open-Meteo-Schnitt. Ortssuche, Beispielorte und Forecast-Abruf liefern ein gemeinsames internes Messwertmodell; Fehler fallen auf manuelle Eingabe zurueck.

Ziel: Einen ersten offenen Wetterdatenpfad fuer Standort- und Ortseingabe definieren.

Empfehlung:

- MVP: Open-Meteo als erste API fuer Forecast-/Current-nahe Wetterwerte
- Spaeter pruefen: DWD Open Data direkt oder ueber Bright Sky/wetterdienst fuer Deutschland-Fokus

Akzeptanzkriterien:

- Die App kann fuer Koordinaten Wetterdaten abrufen.
- Die App kann aus Wetterwerten die benoetigten Feuchtewerte selbst ableiten.
- API-Fehler fuehren zu einem manuellen Fallback statt zu einem blockierten Screen.

### 1.3 Plattformstrategie vorbereiten

Status 2026-05-01: Erledigt fuer den iOS-first MVP. Flutter-Projekt mit Android-, iOS-, macOS- und Web-Konfiguration ist angelegt; iOS-Build, Installation und Standortfluss sind verifiziert. Android ist vorbereitet, wird aber fuer den ersten MVP bewusst nachgelagert, weil lokal Android SDK/cmdline-tools fehlen.

Ziel: Flutter-Projekt so aufsetzen, dass Android und iOS frueh getestet werden.

Akzeptanzkriterien:

- App startet auf Android.
- App startet auf iOS.
- Berechtigungs- und Fallback-Flows werden auf beiden Plattformen eingeplant.

## 2. App-Grundgeruest

### 2.1 Flutter-Projektstruktur erstellen

Status 2026-05-01: Erledigt fuer die MVP-Basis. App-Shell, manuelles Feuchte-Feature und testbare Psychrometrie-Logik sind angelegt; Android/iOS-Konfigurationen wurden durch `flutter create` erzeugt.

Ziel: Eine stabile Basis fuer UI, Berechnung, Datenquellen und lokale Speicherung.

Empfohlene Module:

- `app`: Routing, Theme, App-Shell
- `features/onboarding`: Standort- und Eingabeauswahl
- `features/humidity_calculator`: Eingabe, Berechnung, Ergebnis
- `features/weather`: Wetterdaten-Adapter
- `core/psychrometrics`: Rechenlogik
- `core/storage`: lokale Einstellungen und letzte Eingaben

Akzeptanzkriterien:

- Projekt baut lokal.
- Android- und iOS-Konfigurationen sind vorhanden.
- Die Rechenlogik ist unabhaengig von Widgets testbar.

### 2.2 Designbasis festlegen

Status 2026-05-01: Erledigt als erste Werkzeug-UI. Die App startet direkt im Rechner, nutzt ein ruhiges Material-3-Theme und zeigt Hauptwerte in einer kompakten Arbeitsoberflaeche.

Ziel: Eine ruhige, werkzeugartige UI fuer Einsteiger und fortgeschrittene Nutzer.

Akzeptanzkriterien:

- Einheitliche Farben, Typografie und Abstaende.
- Hauptwerte sind gut lesbar.
- Erweiterte Details lassen sich ausblenden oder einklappen.
- Die App wirkt nicht wie eine Landingpage, sondern wie ein direkt nutzbares Werkzeug.

## 3. Eingabe- und Fallback-Flows

### 3.1 Standort-Onboarding bauen

Status 2026-05-01: Erledigt fuer den iOS-first MVP-Schnitt. Die App hat einen expliziten Standortmodus, fragt Standort nur nach Nutzeraktion an, nutzt Koordinaten fuer denselben Open-Meteo-Wetterfluss und zeigt bei Ablehnung, deaktivierten Diensten oder Timeout normale Ortssuche/manuelle Werte als Fallback. iOS-, Android- und macOS-Konfigurationen fuer die Geolocator-Berechtigung sind vorbereitet; der echte iPhone-Standortfluss wurde auf Device erfolgreich getestet. Android wird bis zur lokalen SDK-Ergaenzung bewusst nachgelagert.

Ziel: Der Default-Start nutzt lokale Daten, wenn der Nutzer zustimmt.

Flow:

1. App erklaert kurz, warum Standort hilfreich ist.
2. Standortberechtigung wird angefragt.
3. Bei Zustimmung werden Koordinaten fuer Wetterdaten genutzt.
4. Bei Ablehnung geht es zur Ortseingabe.

Akzeptanzkriterien:

- Standortfreigabe funktioniert auf Android und iOS.
- Ablehnung ist ein normaler Pfad, kein Fehlerzustand.
- Nutzer koennen spaeter den Modus wechseln.

### 3.2 Ortseingabe bauen

Status 2026-05-01: Erledigt fuer MVP ohne Standortberechtigung. Freie Ortseingabe nutzt Open-Meteo Geocoding und laedt anschliessend Wetterwerte in dieselbe Ergebnisansicht.

Ziel: Nutzer koennen einen Ort manuell waehlen, wenn Standort nicht gewuenscht ist.

Akzeptanzkriterien:

- Ort kann eingegeben werden.
- Ort wird in Koordinaten aufgeloest oder ueber eine API gesucht.
- Ungueltige Eingaben zeigen eine klare Korrekturmoeglichkeit.
- Nutzer koennen zur manuellen Eingabe wechseln.

### 3.3 Beispielorte anbieten

Status 2026-05-01: Erledigt. Hamburg, Berlin, Koeln, Frankfurt am Main und Muenchen sind sichtbar und starten denselben Wetterdatenfluss.

Ziel: Nutzer koennen ohne Standort und ohne freie Ortseingabe mit repraesentativen deutschen Orten starten.

Startliste:

- Hamburg oder Kiel
- Berlin
- Koeln oder Duesseldorf
- Frankfurt am Main
- Muenchen

Akzeptanzkriterien:

- Fuenf Orte sind als Auswahl sichtbar.
- Auswahl startet denselben Wetterdatenfluss wie Ortseingabe.
- Die Liste kann spaeter ohne UI-Umbau angepasst werden.

### 3.4 Vollmanuellen Modus bauen

Status 2026-05-01: Erledigt. Temperatur, relative Luftfeuchte und optionaler Luftdruck koennen manuell eingegeben werden; Ergebnis und Grafik funktionieren ohne Netzwerk.

Ziel: Die App bleibt voll nutzbar ohne Standort, Ort und Wetterdaten.

Akzeptanzkriterien:

- Temperatur kann manuell eingegeben werden.
- Relative Luftfeuchte kann manuell eingegeben werden.
- Luftdruck ist optional und hat einen Defaultwert.
- Ergebnis und Grafik funktionieren ohne Netzwerk.

## 4. Wetterdatenintegration

### 4.1 Open-Meteo Adapter implementieren

Status 2026-05-01: Erledigt. Der Adapter ruft Current-Werte fuer Temperatur, relative Luftfeuchte und optional Surface Pressure ab; Fehler, Timeouts und unvollstaendige Antworten sind behandelt.

Ziel: Erster Wetterdatenabruf ueber eine offene API.

Akzeptanzkriterien:

- Adapter nimmt Koordinaten entgegen.
- Adapter liefert Temperatur, relative Luftfeuchte und wenn verfuegbar Luftdruck.
- Fehler, Timeout und fehlende Werte sind behandelt.
- Der Rest der App haengt nicht direkt an Open-Meteo-spezifischen Datenstrukturen.

### 4.2 Datenquellenmodell vereinheitlichen

Status 2026-05-01: Erledigt fuer manuell, Ort und Beispielort. `WeatherMeasurement` traegt Quelle, Label, Zeitstempel, Datenalter und optionalen Luftdruck.

Ziel: Manuelle Eingabe, Standortwetter und Beispielort liefern dasselbe interne Datenmodell.

Akzeptanzkriterien:

- Gemeinsames Modell fuer Mess-/Eingabewerte.
- Quelle wird gespeichert: manuell, Standort, Ort, Beispielort.
- Zeitstempel und Datenalter sind verfuegbar.

## 5. Berechnungsmodul

### 5.1 Psychrometrische Kernfunktionen implementieren

Status 2026-05-01: Erledigt. Taupunkt, absolute Feuchte, Default-Druck und Feuchtezonen sind in `lib/core/psychrometrics/psychrometrics.dart` gekapselt.

Ziel: Aus Temperatur, relativer Luftfeuchte und optionalem Druck werden abgeleitete Werte berechnet.

Akzeptanzkriterien:

- Taupunkt wird berechnet.
- Absolute Feuchte wird berechnet.
- Ergebniswerte sind fuer typische Wohnraumwerte plausibel.
- Edge Cases werden behandelt, zum Beispiel 0 Prozent, 100 Prozent, negative Temperaturen und fehlender Druck.

### 5.2 Tests fuer Rechenlogik schreiben

Status 2026-05-01: Erledigt. Unit-Tests decken typische Wohnraumwerte, 0 Prozent, 100 Prozent, negative Temperaturen, ungueltige Feuchtewerte und Default-Druck ab.

Ziel: Die fachliche Basis darf nicht durch UI-Aenderungen kaputtgehen.

Akzeptanzkriterien:

- Unit-Tests fuer typische Werte.
- Unit-Tests fuer Grenzwerte.
- Tests laufen ohne Netzwerk und ohne Flutter-Widget-Testumgebung.

## 6. Grafische Darstellung bis MVP

### 6.1 Erste Ergebnisvisualisierung bauen

Status 2026-05-01: Erledigt fuer manuelle Daten. Die UI zeigt Temperatur, relative Feuchte, Taupunkt, absolute Feuchte, Druck und Zone trocken/angenehm/feucht/kritisch.

Ziel: Nutzer sehen sofort, was ihre Eingaben bedeuten.

MVP-Darstellung:

- Aktuelle Temperatur und relative Luftfeuchte
- Taupunkt als klarer Kennwert
- Optional absolute Feuchte in Detailansicht
- Visueller Bereich fuer trocken, angenehm, feucht oder kritisch

Akzeptanzkriterien:

- Ergebnis ist auf kleinen und grossen Displays lesbar.
- Fachbegriffe sind kurz erklaerbar, aber nicht dominant.
- Manuelle und API-Daten sehen in der Darstellung gleichwertig aus.

### 6.2 Temperatur-Feuchte-Grafik bauen

Status 2026-05-01: Erweitert zur interaktiven Arbeitsflaeche. Die Grafik zeigt relative Feuchte ueber Temperatur, markiert aktuellen Punkt und Taupunkt, unterstuetzt Pan/Zoom/Reset und erlaubt das Ziehen des aktuellen Punktes frei oder entlang gleicher absoluter Feuchte.

Ziel: Die App zeigt, bei welchen Temperaturen welche relative Luftfeuchte aus demselben Feuchtegehalt entsteht.

Akzeptanzkriterien:

- Eine Kurve oder Diagramm zeigt relative Luftfeuchte ueber Temperatur.
- Der aktuelle Punkt ist markiert.
- Der Taupunkt ist visuell erkennbar.
- Nutzer koennen den Effekt von Temperaturveraenderung intuitiv verstehen.
- Grafik funktioniert mit manuellen Daten und Wetterdaten.

### 6.3 Einfach-/Profi-Modus vorbereiten

Status 2026-05-01: Erledigt fuer den Rechnerbereich. Die Ergebnisansicht startet im Einfach-Modus mit zentralen Werten und Chart; der Profi-Modus blendet absolute Feuchte, Druck, Quelle, Datenalter, Dampfdruck, Saettigungsdampfdruck und Taupunktabstand ein.

Ziel: Einsteiger werden nicht ueberfordert, fortgeschrittene Nutzer bekommen mehr Tiefe.

Akzeptanzkriterien:

- Einfacher Modus zeigt wenige zentrale Werte.
- Profi-Ansicht oder Detailbereich zeigt zusaetzliche Werte.
- Die App bleibt ohne Account und ohne Sensor nutzbar.

## 7. Lokale Speicherung

### 7.1 Letzte Eingaben und Praeferenzen speichern

Status 2026-05-01: Erledigt fuer den MVP-Rechner. Die App speichert lokal die letzte Quelle, manuelle Werte inklusive optionalem Druck, Ort/Beispielort mit Label und Koordinaten, den letzten Wetterwert sowie Einfach-/Profi-Modus und den offenen Eingabebereich.

Ziel: Nutzer starten nicht jedes Mal bei null.

Akzeptanzkriterien:

- Letzter Modus wird gespeichert.
- Letzte manuelle Werte werden gespeichert.
- Letzter Ort oder Beispielort wird gespeichert, sofern der Nutzer diesen Pfad gewaehlt hat.
- Keine Konto-Pflicht.

### 7.2 Datenschutzfreundlichen Appstart definieren

Status 2026-05-01: Erledigt fuer den aktuellen Quellenumfang. Der Start zeigt gespeicherte lokale Werte ohne Account, Standortberechtigung oder automatische Netzwerkabfrage; gespeicherte Wetterquellen koennen explizit aktualisiert werden.

Ziel: Die App nutzt lokale Daten sinnvoll, ohne Standort oder Konto zu erzwingen.

Akzeptanzkriterien:

- App startet mit gespeicherten lokalen Einstellungen, wenn vorhanden.
- App fragt fehlende Berechtigungen nur dann ab, wenn sie fuer den gewaehlten Modus gebraucht werden.
- Nutzer koennen jederzeit in den manuellen Modus wechseln.

## 8. MVP-Abschluss

### 8.1 MVP-Review

Status 2026-05-01: Erledigt fuer den iOS-first MVP. Die aktuellen App-Pfade decken manuelle Eingabe, Standort, Ortssuche, Beispielorte, Open-Meteo-Wetterwerte, lokale Psychrometrie, Persistenz und die grafische Darstellung ab. Android ist als vorbereiteter, bewusst nachgelagerter Validierungspfad dokumentiert.

Ziel: Pruefen, ob der Kernnutzen erreicht ist.

MVP ist erreicht, wenn:

- iOS laeuft grundlegend; Android ist projektseitig vorbereitet und wird nach SDK-Ergaenzung validiert.
- Standort, Ort, Beispielort und manuelle Eingabe als Pfade vorhanden sind.
- Wetterdaten fuer Standort oder Ort genutzt werden koennen.
- Berechnung von Taupunkt und Feuchtewerten lokal funktioniert.
- Eine grafische Darstellung zeigt, wie relative Luftfeuchte bei anderen Temperaturen entsteht.
- Die App ohne Standort, ohne Konto und ohne Netzwerk im manuellen Modus sinnvoll nutzbar ist.

### 8.2 MVP-Testpaket

Status 2026-05-01: Erledigt fuer den iOS-first MVP und in `docs/MVP_TEST_CHECKLIST.md` dokumentiert. Wetter-API-Fehler, Standort-Ablehnung/Fallback und kleine Displaybreite sind per Tests/Fakes abgedeckt. iOS-Device-Standort ist laut aktuellem Projektstand manuell geprueft. Android-Device-Test ist bewusst aus diesem MVP herausgenommen und bleibt als nachgelagerter Plattformcheck sichtbar.

Ziel: Die erste nutzbare Version gegen Kernrisiken testen.

Akzeptanzkriterien:

- Unit-Tests fuer Rechenlogik laufen.
- Android-Test ist fuer diesen iOS-first MVP bewusst nachgelagert.
- Manuelle Tests auf iOS laufen.
- Wetter-API-Fehlerfall wurde getestet.
- Standort-Ablehnung wurde getestet.
- Kleine Displays wurden geprueft.

Hinweis 2026-05-01: Standort-Ablehnung und Standort-Zustimmung sind technisch per Fake-Service getestet; der echte iPhone-Permission-/GPS-/Wetterpfad wurde laut aktuellem Projektstand manuell erfolgreich geprueft. Android-Permission-Dialog und GPS-Abruf bleiben nach Installation der Android cmdline-tools als separater Plattformcheck offen. Die finale manuelle Release-Pruefung bleibt in `docs/MVP_TEST_CHECKLIST.md` sichtbar.

## 9. Nach dem MVP: Govee H5075

Ziel: Erster lokaler Sensorpfad ueber Bluetooth.

Status 2026-05-01: Paket `9.1-govee-h5075-ble-discovery-spike` implementiert die Discovery-Basis. Die Flutter-App hat einen fakebaren BLE-Scanner-Port, einen `flutter_blue_plus`-Adapter, ein normalisiertes Live-Sensormodell, einen H5075-Parser fuer bekannte passive Manufacturer-Payloads, kopierbare Raw-Samples und eine `Sensor`-Datenquelle, die dekodierte Werte in den Feuchte-Ergebnispfad uebernimmt. iOS-, Android- und macOS-Berechtigungen sind vorbereitet.

Status Paket `9.2-govee-h5075-platform-scan-stabilization`: Das erste echte macOS-Sample `GVH5075_ACC0` ist in Parser- und UI-Tests abgedeckt. Der iPhone-Scanpfad ist mit echter H5075-Hardware validiert: `GVH5075_47EE` wurde bei `-41 dBm` als `22,0 °C`, `29,1 % rF` und `95 %` Batterie dekodiert. Der Batteriebyte-Wert `0x00` aus dem macOS-Capture wird bis zur Gegenpruefung gegen LCD/Govee-App als unbekannt behandelt. Der FlutterBluePlus-macOS-Scan bleibt per Default deaktiviert, weil der native Darwin-Pfad trotz korrekter Bluetooth-Keys in TCC crashte; eine gezielte Probe ist ueber `--dart-define=DEWPROFI_ENABLE_MACOS_FBP_BLE_SCAN=true` moeglich. Details und Testscript stehen in `docs/GOVEE_H5075_DISCOVERY.md`.

Status Paket `9.3-govee-h5075-capability-research-and-probe-plan`: Die Quellenlage fuer passive Advertisements und aktives GATT ist zusammengefuehrt. Gesichert sind passive Livewerte fuer Temperatur, relative Feuchte und meist Batterie; aktiv per GATT sind Device-/Firmware-Informationen, aktuelle Messung/Batterie, Alarme, Offsets und History realistisch, aber noch nicht in dewprofi implementiert. Der Parser nutzt jetzt die durch mehrere Community-Decoder belegte Zehntelgrad-Temperaturformel. Der sichere Probeplan mit Experimentmatrix steht in `docs/GOVEE_H5075_PROBE_PLAN.md`.

Status Paket `9.4-govee-h5075-readonly-gatt-history-probe-spike`: Ein expliziter GATT-History-Probe ist vorbereitet. Die App verbindet nicht automatisch, sondern nur nach Scan und Button `GATT-Probe`; der Port ist fakebar, der FlutterBluePlus-Adapter inventarisiert Services, aktiviert Notifications, sendet nur allowlisted Current-/Battery-/History-Requests und loggt Raw-Responses kopierbar. History-Fenster sind progressiv auf 10 Minuten, 1 Stunde und 24 Stunden begrenzt; der Full-/20-Tage-Abruf bleibt bis nach echter Hardwarevalidierung gesperrt. Ground Truth aus der Govee-App (`Veranda`, `22,0 °C`, `29,5 % rF`, `83 %`, mindestens eine Woche History) und Testscript stehen in `docs/GOVEE_H5075_HISTORY_PROBE.md`.

Status Paket `9.5-govee-h5075-seven-and-twenty-day-history-probe`: Der manuelle GATT-History-Probe kann jetzt nach 10 Minuten, 1 Stunde und 24 Stunden auch 7 Tage anfragen. Ein 20-Tage-/28800-Minuten-Probe ist als experimenteller Langtest vorbereitet, aber nur nach expliziter UI-Bestaetigung und mit sichtbarer Warnung erreichbar. Timeouts sind fuer 7 Tage und 20 Tage laenger, aber begrenzt; Raw-GATT-Log, Record-Count sowie erste/letzte History-Records bleiben kopierbar. Echte iPhone/H5075-Validierung der langen Fenster ist angelaufen und hat reale History-Records geliefert.

Status Paket `9.6-govee-h5075-history-chunking-and-resume`: Der Read-only-GATT-Probe modelliert History-Abrufe jetzt als konkrete Chunks `start -> end`, dedupliziert Records nach `minutesBack` und diagnostiziert Range, aeltesten/neuesten Record sowie den naechsten empfohlenen Chunk. Partial 20-Tage-Runs wie `-28800m..-14997m` schlagen dadurch manuell `14996 -> 1` als Folgechunk vor; die UI zeigt Chunk, Unique Count, Range und einen expliziten `Folgechunk`-Button. Die Allowlist bleibt auf Current/Battery/History-Read-Requests begrenzt, ohne automatische GATT-Verbindung oder Config-Writes. Praktisch positiv getestet sind Folgechunks bis zur neuesten Minute, zuletzt `2306 -> 1` mit `2114` eindeutigen Records und Range `-2306m..-1m` am 2026-05-02.

Status Paket `9.7-govee-h5075-thirty-day-experimental-probe`: Fuer die Hardware-Grenzprobe gibt es nun zusaetzlich ein bestaetigungspflichtiges `30 d`-Fenster (`43200 -> 1`, Request `33 01 a8 c0 00 01 ... 5b`). Das bleibt explizit unbestaetigt und experimentell: Es erweitert nur die manuelle Read-only-Probe, nicht den Produktpfad, und nutzt weiterhin ausschliesslich den allowlisted History-Read.

Status Paket `9.8-govee-h5075-history-visualization`: Geladene H5075-History-Records koennen nun in einer Govee-nahen Historienansicht dargestellt werden. Die Ansicht nutzt einen blauen Sensor-Header mit aktuellen Temperatur-/Feuchtewerten, Anzeigezeitraeume `Stunde`, `Tag`, `Woche`, `Monat`, `Jahr` und zwei Chartkarten fuer Temperatur und relative Luftfeuchtigkeit. Das ViewModel dedupliziert nach beobachteter Minute, berechnet Max/Avg/Min, Coverage und Gap-Marker, und die CustomPainter-Charts brechen Linien bei groesseren Datenluecken. Die Ansicht wurde mit einem echten erfolgreichen H5075-Folgechunk praktisch positiv geprueft.

Status Paket `9.9-govee-h5075-auto-resume-and-history-navigation`: Lange H5075-History-Abrufe laufen nach dem manuell gestarteten GATT-Probe jetzt innerhalb derselben Verbindung automatisch ueber Folgechunks weiter, bis die neueste Minute erreicht ist oder ein Fehler/Abbruch stoppt. Die Auto-Resume-Logik nutzt weiterhin nur allowlisted Read-Requests (`aa01`, `aa08`, `3301`), baut keine automatische GATT-Verbindung auf und plant Folgechunks aus der beobachteten Range. Die Historienansicht kann pro Diagramm horizontal vergroessert und gescrollt werden, damit verdichtete Mehrtagesdaten inspizierbar bleiben.

Geplanter Umfang:

- BLE-Scan fuer H5075: Basis erledigt; iOS-Hardware-Validierung erfolgreich, macOS-Pluginpfad wegen TCC-Crash gegated.
- Passive Advertisement-Decodierung fuer Live-Werte: bekannte Manufacturer-Payload und erstes echtes Sample testbar, weitere Firmware-Samples offen.
- Normalisiertes Datenmodell fuer Temperatur, relative Luftfeuchte, Batterie, Zeitstempel und Quelle: Basis erledigt.
- Rohdaten-Samples fuer Parser-Debugging: Basis erledigt, erstes echtes Sample dokumentiert.
- GATT/History-Probe: Read-only-Spike vorbereitet; 7d, bestaetigter 20d-Probe
  und bestaetigungspflichtiger 30d-Grenztest sind probierbar. Partial
  Downloads werden innerhalb des manuell gestarteten Probe-Laufs ueber
  allowlisted Folgechunks automatisch fortgesetzt.
- H5075-History-Darstellung: Erste Govee-nahe iOS-Ansicht mit Zeitraum-Tabs,
  Temperatur-/Feuchte-Charts, Statistiken, Coverage-Diagnose sowie
  horizontalem Zoom/Scroll ist integriert.

Diese Phase gehoert nicht mehr zum ersten MVP.

## 10. Nach dem MVP: Weitere Govee-Geraete

Ziel: Architektur von H5075 auf weitere Govee-BLE-Hygrometer erweitern.

Geplanter Umfang:

- Geraeteerkennung abstrahieren
- Parser pro Modell kapseln
- Kompatibilitaetsliste pflegen
- Fallback fuer unbekannte Govee-Payloads definieren

## 11. Nach dem MVP: Notifications

Ziel: Nutzer aktiv warnen, wenn Grenzwerte unter- oder ueberschritten werden.

Geplanter Umfang:

- Lokale Grenzwerte pro Profil
- App-Benachrichtigungen
- Spaeter Push-Notifications
- Spaeter E-Mail
- Spaeter externe Kanaele wie WhatsApp

Beispielregel:

- Bei 20 Grad unter 45 Prozent relativer Luftfeuchte warnen.
- Bei 20 Grad ueber 55 Prozent relativer Luftfeuchte warnen.

## 12. Nach dem MVP: Account und Synchronisierung

Ziel: Lokale Nutzung bleibt moeglich, Konto wird optional fuer Sync und Backup.

Geplanter Umfang:

- Anonyme lokale Nutzung
- Optionaler Account
- Profil- und Einstellungssync
- Geraetesync
- Spaeter Verlaufsdaten-Sync

Grundsatz:

- Ohne Account darf die App nicht kuenstlich eingeschraenkt wirken.
- Mit Account werden Komfort, Backup und Mehrgeraetenutzung besser.
