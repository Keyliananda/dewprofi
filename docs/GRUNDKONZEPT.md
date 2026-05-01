# dewprofi Grundkonzept

## 1. Produktidee

dewprofi wird eine Flutter-App, die Luftfeuchtigkeit so erklaert und visualisiert, dass ein unwissender Nutzer einsteigen kann und sich schrittweise wie ein Profi orientiert. Die App soll nicht nur Zahlen anzeigen, sondern sichtbar machen, was relative Luftfeuchte, Temperatur, Taupunkt und spaeter Sensorwerte praktisch bedeuten.

Der erste Produktkern ist ein anschaulicher Feuchte-Rechner mit grafischer Darstellung: Nutzer geben Temperatur und relative Luftfeuchte manuell ein oder lassen lokale Wetterdaten verwenden. Die App zeigt daraus verstaendlich, bei welchen Temperaturen welche relative Luftfeuchte entsteht und wie sich die Situation im Raum oder am Standort einordnen laesst.

Langfristig wird dewprofi zu einem persoenlichen Feuchte-Assistenten mit lokalen Sensoren, Govee-Bluetooth-Anbindung, Profilen, Synchronisierung und Warnungen bei kritischen Grenzwerten.

## 2. Zielgruppe

Die App richtet sich an Nutzer, die wenig Vorwissen ueber Luftfeuchtigkeit haben, aber bessere Entscheidungen treffen wollen:

- Privatpersonen in Wohnung oder Haus
- Mieter und Eigentuemer mit Schimmel-, Komfort- oder Heizthemen
- Nutzer von Hygrometern, die Messwerte besser verstehen wollen
- Fortgeschrittene Anwender, die nachvollziehbare Kennzahlen und Diagramme erwarten

Die Bedienung muss fuer Einsteiger niedrigschwellig bleiben. Die fachliche Tiefe soll optional zunehmen: erst klare Visualisierung, danach erklaerende Details, Formeln, Verlauf, Sensoren und Profile.

## 3. Hauptnutzen

dewprofi kombiniert zwei Nutzungsarten:

- Visualisieren: Feuchtewerte werden grafisch, vergleichbar und intuitiv dargestellt.
- Erklaeren: Optional erhaelt der Nutzer kurze Erklaerungen, warum ein Wert unkritisch, auffaellig oder kritisch sein kann.

Die erste App-Version konzentriert sich auf die Visualisierung. Erklaertexte duerfen helfen, sollen aber nicht die Hauptoberflaeche ueberladen. Der Nutzer soll auch ohne Fachwissen erkennen koennen:

- Wie veraendert sich relative Luftfeuchte bei anderer Temperatur?
- Wo liegt der aktuelle Wert im Komfort- oder Risikobereich?
- Wann wird ein Wert trockener, feuchter oder taupunktnah?
- Was bedeutet der Wert im gaengigen Format relative Luftfeuchte?

## 4. Kernbegriffe und Berechnungslogik

Die App arbeitet langfristig mit mehreren psychrometrischen Groessen, stellt aber zuerst die gaengigsten Werte in den Vordergrund:

- Relative Luftfeuchte in Prozent als primaerer Nutzerwert
- Temperatur in Grad Celsius
- Taupunkt als wichtige Orientierungszahl
- Absolute Feuchte in g/m3 als technische Zwischengroesse und optional sichtbarer Wert
- Luftdruck als optionaler Einflusswert

Fuer den Luftdruck wird ein sinnvoller Standardwert genutzt, wenn keine Quelle vorhanden ist. Der Default kann mit 1013,25 hPa starten. Spaeter kann der Wert aus Standortdaten, Wetter-API oder Geraetesensoren uebernommen werden, sofern die Plattform dies zulaesst.

Die App soll Berechnungen lokal ausfuehren. Wetter- und Sensordaten liefern Eingabewerte; die psychrometrische Ableitung bleibt nachvollziehbar in der App. Dadurch bleibt die App auch fuer manuelle Nutzung und Offline-Szenarien brauchbar.

## 5. Datenquellen im MVP

### 5.1 Standort als bevorzugter Startpfad

Beim ersten Start versucht dewprofi, mit lokalen Daten zu arbeiten. Wenn Standortdaten noch nicht freigegeben sind, fragt die App die Berechtigung an.

Der Einstieg folgt dieser Reihenfolge:

1. Standortfreigabe anfragen und lokale Wetterdaten nutzen.
2. Bei Ablehnung eine manuelle Ortseingabe anbieten.
3. Wenn keine Ortseingabe gewuenscht ist, fuenf repraesentative deutsche Orte anbieten.
4. Wenn auch das nicht gewuenscht ist, vollstaendig manuelle Feuchtewerte nutzen.

Die App darf nicht blockieren, nur weil kein Standort verfuegbar ist. Standortdaten verbessern den Startwert, sind aber keine Pflicht.

### 5.2 Repraesentative Orte fuer Deutschland

Als Fallback-Auswahl werden fuenf Orte vorgeschlagen, die grob unterschiedliche Regionen Deutschlands abdecken:

- Hamburg oder Kiel fuer Nord-/Kuesteneinfluss
- Berlin fuer Nordost/urbanes Binnenklima
- Koeln oder Duesseldorf fuer Westen/Rheinland
- Frankfurt am Main fuer Mitte/urbanes Binnenklima
- Muenchen fuer Sueden/Voralpenraum

Die konkrete Liste kann spaeter anhand Datenqualitaet, API-Abdeckung und Produkttext finalisiert werden.

### 5.3 Wetterdienst

Es gibt aktuell keine feste Praeferenz fuer den Wetterdienst. Fuer das MVP ist Open-Meteo der naheliegende Kandidat, weil es eine frei nutzbare, quelloffene Wetter-API mit einfacher HTTP-Abfrage gibt. Fuer Deutschland kann spaeter geprueft werden, ob DWD Open Data ueber eine Zwischenschicht wie Bright Sky oder wetterdienst besser geeignet ist.

Wichtig: Viele Wetterdienste liefern Temperatur, relative Feuchte und Druck, aber nicht zwingend direkt absolute Feuchte. dewprofi sollte absolute Feuchte deshalb selbst aus den gelieferten Eingaben berechnen.

Quellen zur Orientierung:

- Open-Meteo Dokumentation: https://open-meteo.com/en/docs
- Open-Meteo Repository: https://github.com/open-meteo/open-meteo
- DWD Open Data: https://www.dwd.de/EN/ourservices/opendata/opendata.html

## 6. MVP-Funktionsumfang

Das MVP ist erreicht, wenn die App aus Standort-, Orts- oder manuellen Eingaben eine verstaendliche grafische Darstellung erzeugt.

MVP muss enthalten:

- Flutter-App-Grundgeruest fuer Android und iOS
- Fruehes Testen auf beiden Plattformen
- Onboarding fuer Standort, Ortseingabe, Beispielorte und manuelle Nutzung
- Manuelle Eingabe von Temperatur und relativer Luftfeuchte
- Optionaler Luftdruck mit Defaultwert
- Wetterdatenabruf fuer einen Standort oder Ort
- Lokale Berechnung von Taupunkt und abgeleiteten Feuchtewerten
- Grafische Darstellung, wie sich relative Luftfeuchte bei Temperaturveraenderung verhaelt
- Einfache Bewertung der aktuellen Situation, ohne Nutzer zu ueberfordern
- Lokale Speicherung der letzten Einstellungen und Eingaben

Nicht Teil des ersten MVP:

- Notifications
- Account und Cloud-Sync
- Govee-Bluetooth-Anbindung
- Mail-, WhatsApp- oder externe Alarmkanaele
- Historische Sensorverlaeufe

## 7. UX-Prinzipien

Die App soll wie ein Werkzeug wirken, nicht wie ein Fachbuch. Der erste Screen soll sofort nutzbar sein und die wichtigsten Werte klar zeigen.

Grundsaetze:

- Default zuerst: Standort oder lokaler Startwert, wenn moeglich.
- Kein Zwang: Jeder automatische Schritt hat einen manuellen Fallback.
- Erst sehen, dann erklaeren: Die Grafik ist wichtiger als langer Text.
- Fachlichkeit optional: Einsteiger sehen klare Labels, Profis koennen Details oeffnen.
- Jede Zahl braucht Kontext: Relative Feuchte, Taupunkt und Temperatur werden gemeinsam bewertet.

Ein moeglicher Startscreen:

- Aktueller Modus: Standort, Ort, Beispielort oder Manuell
- Eingabewerte: Temperatur, relative Luftfeuchte, optional Druck
- Hauptvisualisierung: Kurve oder Diagramm, das relative Feuchte bei verschiedenen Temperaturen zeigt
- Ergebnisbereich: Taupunkt, absolute Feuchte, kurze Bewertung
- Umschalter: einfach / erweitert

## 8. Spaetere Ausbaulinien

### 8.1 Govee Bluetooth

Die erste Sensorintegration soll das Govee H5075 Hygrometer sein. Laut Projektkontext ist der bevorzugte Weg eine lokale BLE-Anbindung:

- Passive BLE-Advertisements fuer Live-Werte
- Aktive GATT-Verbindung nur fuer History-Sync
- Speicherung normalisierter Messwerte mit Zeitstempel, Temperatur, relativer Feuchte, Batterie und Quelle
- Rohdaten-Samples in der Entwicklungsphase zur Parser-Validierung

Nach H5075 soll die Architektur auf weitere Govee-BLE-Hygrometer erweitert werden.

### 8.2 Notifications

Notifications kommen nach dem MVP. Sie sollen Nutzer warnen, wenn eingestellte Grenzen unter- oder ueberschritten werden, zum Beispiel:

- Relative Luftfeuchte bei 20 Grad faellt unter 45 Prozent.
- Relative Luftfeuchte bei 20 Grad steigt ueber 55 Prozent.
- Taupunkt oder Feuchteverlauf deutet auf ein Risiko hin.

Prioritaet der Kanaele:

1. App-Benachrichtigung lokal oder Push
2. E-Mail
3. Externe Messenger-Kanaele wie WhatsApp als spaetere Integration

### 8.3 Account und Synchronisierung

dewprofi soll ohne Konto funktionieren. Nutzer koennen anonym mit lokalen Appdaten starten. Ein Account wird optional, wenn Profile, Einstellungen, Geraete und Verlaeufe zwischen mehreren Installationen synchronisiert werden sollen.

Grundsatz:

- Ohne Account: lokale Nutzung, lokale Einstellungen, manuelle und ggf. lokale Sensorwerte
- Mit Account: Backup, Sync, mehrere Geraete, Profilverwaltung

## 9. Technische Leitplanken

- Flutter als gemeinsame Codebasis fuer Android und iOS
- Fruehes Plattformtesten auf Android und iOS, besonders fuer Berechtigungen
- Lokale Berechnungslogik getrennt von UI und Datenquellen
- Datenquellen austauschbar halten: manuell, Standort, Wetter-API, BLE, spaeter Account
- Offline-faehiger Kern fuer manuelle Berechnung
- Datenschutzfreundlicher Default: keine Konto-Pflicht, keine Standortpflicht
- Klare Trennung zwischen MVP und spaeteren Integrationen

## 10. Erfolgskriterium des MVP

Das MVP ist erfolgreich, wenn ein Nutzer ohne Vorwissen in weniger als einer Minute einen Feuchtewert eingeben oder automatisch laden kann und danach grafisch versteht, wie sich die relative Luftfeuchte bei anderen Temperaturen veraendert.

Die App muss sich dabei auch dann sinnvoll verhalten, wenn Standort, Ortseingabe und Wetterdienst nicht genutzt werden.
