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

Status 2026-05-01: Teilweise erledigt. Flutter-Projekt mit Android-, iOS-, macOS- und Web-Konfiguration ist angelegt. iOS-Debug-Build fuer ein verbundenes iPhone ist erfolgreich, App-Installation auf das iPhone lief mit Exit-Code 0. Android bleibt lokal durch fehlendes Android SDK blockiert.

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

Ziel: Pruefen, ob der Kernnutzen erreicht ist.

MVP ist erreicht, wenn:

- Android und iOS grundlegend laufen.
- Standort, Ort, Beispielort und manuelle Eingabe als Pfade vorhanden sind.
- Wetterdaten fuer Standort oder Ort genutzt werden koennen.
- Berechnung von Taupunkt und Feuchtewerten lokal funktioniert.
- Eine grafische Darstellung zeigt, wie relative Luftfeuchte bei anderen Temperaturen entsteht.
- Die App ohne Standort, ohne Konto und ohne Netzwerk im manuellen Modus sinnvoll nutzbar ist.

### 8.2 MVP-Testpaket

Ziel: Die erste nutzbare Version gegen Kernrisiken testen.

Akzeptanzkriterien:

- Unit-Tests fuer Rechenlogik laufen.
- Manuelle Tests auf Android laufen.
- Manuelle Tests auf iOS laufen.
- Wetter-API-Fehlerfall wurde getestet.
- Standort-Ablehnung wurde getestet.
- Kleine Displays wurden geprueft.

## 9. Nach dem MVP: Govee H5075

Ziel: Erster lokaler Sensorpfad ueber Bluetooth.

Geplanter Umfang:

- BLE-Scan fuer H5075
- Passive Advertisement-Decodierung fuer Live-Werte
- Normalisiertes Datenmodell fuer Temperatur, relative Luftfeuchte, Batterie, Zeitstempel und Quelle
- Rohdaten-Samples fuer Parser-Debugging
- GATT/History-Sync als spaetere Erweiterung nach Live-Werten

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
