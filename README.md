# dewprofi

Flutter-App fuer den visuellen Feuchte-Rechner-MVP. Zusaetzlich liegen ein Laravel-API-Backend und ein separates React/Vite-Frontend als Web-Stack in `backend/` und `frontend/`.

## Was aktuell funktioniert

- Manuelle Eingabe von Temperatur, relativer Luftfeuchte und optionalem Luftdruck.
- Datenquelle kann zwischen manueller Eingabe, Standort, Ortssuche und fuenf Beispielorten wechseln.
- Open-Meteo liefert Wetterwerte fuer Standort, Orte und Koordinaten; bei Fehlern bleibt der manuelle Pfad nutzbar.
- Letzte Quelle, Werte, Ort/Beispielort und Einfach-/Profi-Modus werden lokal wiederhergestellt.
- Standort wird nicht beim Appstart abgefragt, sondern nur nach explizitem Tippen auf `Standort verwenden`.
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

Der Open-Meteo-Pfad nutzt Netzwerk nur zur Laufzeit. Tests mocken Standort, Geocoding und Forecast, damit sie offline stabil bleiben.

Der Standortmodus ist auf dem iPhone manuell geprueft: Auswahl von `Standort`, explizites `Standort verwenden`, iOS-Berechtigungsdialog, GPS-basierter Wetterabruf und Fallback-Verhalten bleiben normale App-Pfade. Android ist fuer diesen iOS-first MVP bewusst nachgelagert, weil lokal die Android cmdline-tools fehlen. Die finale MVP-Checkliste mit automatisierten Nachweisen und Device-Szenarien liegt in `docs/MVP_TEST_CHECKLIST.md`.

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

Android ist im Projekt konfiguriert, fuer den iOS-first MVP aber noch nicht validiert. Nach Installation von Android Studio/SDK sollte `flutter doctor` den verbleibenden Android-Setup-Status zeigen.

## Laravel API und separates Frontend

Backend vorbereiten:

```sh
cd backend
composer install
php artisan migrate
herd link api.dewprofi
```

Frontend fuer Herd bauen und verlinken:

```sh
cd frontend
npm install
npm run build
cd dist
herd link app.dewprofi
```

Optionaler Vite-Dev-Server fuer Live-Entwicklung:

```sh
cd frontend
npm run dev
```

Empfohlene lokale URLs:

- Frontend: `http://app.dewprofi.test`
- API: `http://api.dewprofi.test`

Das Frontend erwartet die API unter `http://api.dewprofi.test`. Bei anderer Backend-URL `frontend/.env` nach `frontend/.env.example` anlegen und `VITE_API_BASE_URL` setzen. Die API bietet `POST /api/register`, `POST /api/login`, `GET /api/me`, `POST /api/logout` und `GET /api/health`.

Der Web-Stack bildet die Flutter-Kernfunktionen ab: manuelle Werte, Ortssuche,
Beispielorte, Open-Meteo-Wetterwerte, Taupunkt/absolute Feuchte/Zonen,
Einfach-/Profi-Details und eine interaktive Temperatur-Feuchte-Grafik mit
Ziehen, Kurvensperre, Pan, Zoom und Reset.
