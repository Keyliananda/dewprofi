# MVP Test Checklist

Stand: 2026-05-01

## Automated MVP Evidence

- `flutter analyze`
- `flutter test`
- `flutter build ios --debug --no-codesign`
- `flutter build macos --debug`
- `plutil -lint ios/Runner/Info.plist macos/Runner/Info.plist macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements`
- `flutter doctor -v` to record that Android validation is intentionally deferred until SDK setup

Covered by automated tests:

- Local psychrometric calculations for dew point, absolute humidity, pressure defaults and input validation.
- Manual input, place search, example places, saved weather values and saved location values.
- Open-Meteo geocoding and weather parsing, including HTTP failures, malformed responses and missing weather data.
- Weather API failure in the calculator UI falls back to manual input, including failures after a successful place lookup.
- Location mode waits for the explicit `Standort verwenden` action.
- Location denial/service errors in the calculator UI fall back to place search/manual values without fetching weather.
- Small display layout for the expanded calculator controls at 320 x 568 logical pixels.

## Manual Device Checks

Run before tagging or shipping the MVP:

1. iOS: fresh install, open app, confirm no location prompt appears on startup.
2. iOS: expand input, choose `Standort`, tap `Standort verwenden`, allow permission, confirm GPS-based weather result appears.
3. iOS: repeat with location permission denied or disabled, confirm the app shows the fallback message and keeps place search/manual input usable.
4. iOS: on a small iPhone viewport, open manual, location, place and example paths; confirm no clipped primary controls.
5. Offline/network failure: disable network or intercept Open-Meteo, search a place, and confirm manual values remain usable.

## Deferred Platform Checks

- Android is intentionally out of scope for this iOS-first MVP until Android SDK/cmdline-tools are installed.
- After Android setup, run `flutter doctor -v`, `flutter build apk --debug` or `flutter run`, then repeat startup, location allow and location denial checks on a real device or emulator.
- Automated fakes cover location denial and weather failure, but native Android permission dialogs and GPS accuracy still require later device validation.
