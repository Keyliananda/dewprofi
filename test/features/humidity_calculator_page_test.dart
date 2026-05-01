import 'package:dewprofi/app/dewprofi_app.dart';
import 'package:dewprofi/features/weather/weather_measurement.dart';
import 'package:dewprofi/features/weather/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual calculator renders default result', (tester) async {
    await tester.pumpWidget(const DewprofiApp());

    expect(find.text('Manuelle Eingabe'), findsOneWidget);
    expect(find.text('Taupunkt'), findsOneWidget);
    expect(find.text('Absolute Feuchte'), findsOneWidget);
    expect(find.text('angenehm'), findsOneWidget);
    expect(find.byKey(const ValueKey('humidity-curve-chart')), findsOneWidget);
  });

  testWidgets('manual input updates the humidity zone', (tester) async {
    await tester.pumpWidget(const DewprofiApp());

    await tester.enterText(
      find.widgetWithText(TextField, 'Relative Luftfeuchte'),
      '75',
    );
    await tester.pump();

    expect(find.text('kritisch'), findsOneWidget);
  });

  testWidgets('optional pressure accepts comma decimals', (tester) async {
    await tester.pumpWidget(const DewprofiApp());

    await tester.enterText(
      find.widgetWithText(TextField, 'Temperatur'),
      '19,5',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Luftdruck optional'),
      '990,5',
    );
    await tester.pump();

    expect(find.text('19,5 °C'), findsOneWidget);
    expect(find.text('990,50 hPa'), findsOneWidget);
  });

  testWidgets('example places load through the shared result view', (
    tester,
  ) async {
    final weatherService = _FakeWeatherService(
      measurement: _measurement(
        label: 'Berlin, Berlin',
        source: MeasurementSource.examplePlace,
      ),
    );
    await tester.pumpWidget(DewprofiApp(weatherService: weatherService));

    await tester.tap(find.text('Beispiele'));
    await tester.pumpAndSettle();

    expect(find.text('Hamburg'), findsOneWidget);
    expect(find.text('Berlin'), findsOneWidget);
    expect(find.text('Koeln'), findsOneWidget);
    expect(find.text('Frankfurt am Main'), findsOneWidget);
    expect(find.text('Muenchen'), findsOneWidget);

    await tester.tap(find.text('Berlin'));
    await tester.pumpAndSettle();

    expect(find.text('Berlin, Berlin'), findsOneWidget);
    expect(find.textContaining('beispielort'), findsOneWidget);
    expect(find.text('Datenalter'), findsOneWidget);
    expect(find.text('18,0 °C'), findsOneWidget);

    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();

    expect(find.text('Manuelle Eingabe'), findsOneWidget);
    expect(find.text('21,0 °C'), findsOneWidget);
  });

  testWidgets('place search resolves coordinates and loads weather', (
    tester,
  ) async {
    final weatherService = _FakeWeatherService(
      measurement: _measurement(label: 'Hamburg, Hamburg'),
    );
    await tester.pumpWidget(DewprofiApp(weatherService: weatherService));

    await tester.tap(find.text('Ort'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ort suchen'), 'HH');
    await tester.tap(find.text('Wetter laden'));
    await tester.pumpAndSettle();

    expect(weatherService.lastSearchQuery, 'HH');
    expect(find.text('Hamburg, Hamburg'), findsOneWidget);
    expect(find.textContaining('ort'), findsOneWidget);
  });

  testWidgets('weather errors fall back to manual input', (tester) async {
    final weatherService = _FakeWeatherService(
      error: const WeatherServiceException('Ort nicht gefunden.'),
    );
    await tester.pumpWidget(DewprofiApp(weatherService: weatherService));

    await tester.tap(find.text('Ort'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ort suchen'), 'xx');
    await tester.tap(find.text('Wetter laden'));
    await tester.pumpAndSettle();

    expect(find.text('Ort nicht gefunden.'), findsOneWidget);
    expect(find.text('Manuelle Eingabe'), findsOneWidget);
    expect(find.text('21,0 °C'), findsOneWidget);
  });
}

WeatherMeasurement _measurement({
  String label = 'Hamburg, Hamburg',
  MeasurementSource source = MeasurementSource.place,
}) {
  final observedAt = DateTime(2026, 5, 1, 10);
  return WeatherMeasurement(
    temperatureCelsius: 18,
    relativeHumidityPercent: 62,
    pressureHPa: 1007,
    source: source,
    label: label,
    observedAt: observedAt,
    fetchedAt: observedAt.add(const Duration(minutes: 1)),
  );
}

class _FakeWeatherService implements WeatherService {
  _FakeWeatherService({WeatherMeasurement? measurement, this.error})
    : measurement = measurement ?? _measurement();

  final WeatherMeasurement measurement;
  final Object? error;
  String? lastSearchQuery;

  @override
  Future<List<WeatherPlace>> searchPlaces(String query) async {
    lastSearchQuery = query;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return const [
      WeatherPlace(
        name: 'Hamburg',
        country: 'Deutschland',
        admin1: 'Hamburg',
        coordinates: WeatherCoordinates(latitude: 53.55, longitude: 9.99),
      ),
    ];
  }

  @override
  Future<WeatherMeasurement> fetchWeather({
    required WeatherCoordinates coordinates,
    required MeasurementSource source,
    required String label,
  }) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return measurement;
  }

  @override
  Future<WeatherMeasurement> fetchWeatherForPlace({
    required WeatherPlace place,
    required MeasurementSource source,
  }) {
    return fetchWeather(
      coordinates: place.coordinates,
      source: source,
      label: place.displayName,
    );
  }
}
