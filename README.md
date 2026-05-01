# dewprofi

Flutter-App fuer den visuellen Feuchte-Rechner-MVP.

## Was aktuell funktioniert

- Manuelle Eingabe von Temperatur, relativer Luftfeuchte und optionalem Luftdruck.
- Datenquelle kann zwischen manueller Eingabe, Ortssuche und fuenf Beispielorten wechseln.
- Open-Meteo liefert Wetterwerte fuer Orte/Koordinaten; bei Fehlern bleibt der manuelle Pfad nutzbar.
- Lokale Berechnung von Taupunkt und absoluter Feuchte ohne Netzwerk.
- Erste Ergebnisvisualisierung mit Feuchtezone und Temperatur-Feuchte-Grafik.
- iOS-, Android-, macOS- und Web-Projektstruktur ist angelegt.

## Lokal starten

Flutter wurde lokal per Homebrew installiert:

```sh
flutter --version
```

Tests und Analyse:

```sh
flutter test
flutter analyze
```

Der Open-Meteo-Pfad nutzt Netzwerk nur zur Laufzeit. Tests mocken Geocoding und Forecast, damit sie offline stabil bleiben.

Auf dem angeschlossenen iPhone starten:

```sh
flutter devices
flutter run -d 00008130-000A29CE0E51001C
```

Falls das iPhone nicht angezeigt wird, entsperren, diesem Mac vertrauen und optional per USB verbinden. Der iOS-Debug-Build wurde mit dem vorhandenen Development Team `76XQMR6H48` erfolgreich erzeugt und die App wurde auf das erkannte iPhone installiert.

macOS-Fallback lokal:

```sh
flutter run -d macos
```

Android ist im Projekt konfiguriert, lokal aber noch nicht startbar, weil kein Android SDK gefunden wurde. Nach Installation von Android Studio/SDK sollte `flutter doctor` den verbleibenden Android-Setup-Status zeigen.
