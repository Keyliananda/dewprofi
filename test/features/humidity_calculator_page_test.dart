import 'dart:math' as math;

import 'package:dewprofi/app/dewprofi_app.dart';
import 'package:dewprofi/core/storage/calculator_preferences_store.dart';
import 'package:dewprofi/core/psychrometrics/psychrometrics.dart';
import 'package:dewprofi/features/location/location_service.dart';
import 'package:dewprofi/features/weather/weather_measurement.dart';
import 'package:dewprofi/features/weather/weather_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual calculator renders default result', (tester) async {
    await _pumpCalculator(tester);

    expect(find.text('Manuelle Eingabe'), findsOneWidget);
    expect(find.text('Taupunkt'), findsOneWidget);
    expect(find.text('Absolute Feuchte'), findsNothing);
    expect(find.text('angenehm'), findsOneWidget);
    expect(find.byKey(const ValueKey('humidity-curve-chart')), findsOneWidget);
  });

  testWidgets('pro mode reveals extended psychrometric details', (
    tester,
  ) async {
    await _pumpCalculator(tester);

    await _switchToProMode(tester);

    expect(find.text('Absolute Feuchte'), findsOneWidget);
    expect(find.text('Druck'), findsOneWidget);
    expect(find.text('Saettigungsdampfdruck'), findsOneWidget);
    expect(find.text('Dampfdruck'), findsOneWidget);
    expect(find.text('Taupunktabstand'), findsOneWidget);
    expect(find.text('Quelle'), findsOneWidget);
    expect(find.text('Datenalter'), findsOneWidget);
    expect(find.byKey(const ValueKey('humidity-curve-chart')), findsOneWidget);
  });

  testWidgets('manual input updates the humidity zone', (tester) async {
    await _pumpCalculator(tester);
    await _expandInput(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Relative Luftfeuchte'),
      '75',
    );
    await tester.pump();

    expect(find.text('kritisch'), findsOneWidget);
  });

  testWidgets('optional pressure accepts comma decimals', (tester) async {
    await _pumpCalculator(tester);
    await _expandInput(tester);

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
    await _switchToProMode(tester);

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
    await _pumpCalculator(tester, weatherService: weatherService);
    await _expandInput(tester);

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
    expect(find.textContaining('beispielort'), findsWidgets);
    await _switchToProMode(tester);

    expect(find.text('Datenalter'), findsOneWidget);
    expect(find.text('18,0 °C', skipOffstage: false), findsOneWidget);

    await tester.ensureVisible(find.text('Datenquelle'));
    await tester.pumpAndSettle();
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
    await _pumpCalculator(tester, weatherService: weatherService);
    await _expandInput(tester);

    await tester.tap(find.text('Ort'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ort suchen'), 'HH');
    await tester.tap(find.text('Wetter laden'));
    await tester.pumpAndSettle();

    expect(weatherService.lastSearchQuery, 'HH');
    expect(find.text('Hamburg, Hamburg'), findsOneWidget);
    expect(find.textContaining('ort'), findsWidgets);
  });

  testWidgets('location mode waits for explicit use action', (tester) async {
    final locationService = _FakeLocationService();
    final weatherService = _FakeWeatherService(
      measurement: _measurement(
        label: 'Aktueller Standort',
        source: MeasurementSource.location,
      ),
    );
    await _pumpCalculator(
      tester,
      weatherService: weatherService,
      locationService: locationService,
    );
    await _expandInput(tester);

    await tester.tap(find.text('Standort'));
    await tester.pumpAndSettle();

    expect(locationService.requestCount, 0);
    expect(weatherService.fetchCount, 0);
    expect(find.text('Standort verwenden'), findsOneWidget);
  });

  testWidgets('location mode loads weather through shared result view', (
    tester,
  ) async {
    final locationService = _FakeLocationService(
      coordinates: const WeatherCoordinates(latitude: 53.55, longitude: 9.99),
    );
    final weatherService = _FakeWeatherService(
      measurement: _measurement(
        label: 'Aktueller Standort',
        source: MeasurementSource.location,
      ),
    );
    await _pumpCalculator(
      tester,
      weatherService: weatherService,
      locationService: locationService,
    );
    await _expandInput(tester);

    await tester.tap(find.text('Standort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standort verwenden'));
    await tester.pumpAndSettle();

    expect(locationService.requestCount, 1);
    expect(weatherService.lastCoordinates?.latitude, 53.55);
    expect(weatherService.lastCoordinates?.longitude, 9.99);
    expect(find.text('Aktueller Standort'), findsOneWidget);
    expect(find.textContaining('standort'), findsWidgets);
  });

  testWidgets('location errors fall back to place search', (tester) async {
    final locationService = _FakeLocationService(
      error: const LocationServiceException(
        'Standortfreigabe wurde abgelehnt. Du kannst stattdessen einen Ort suchen.',
      ),
    );
    final weatherService = _FakeWeatherService();
    await _pumpCalculator(
      tester,
      weatherService: weatherService,
      locationService: locationService,
    );
    await _expandInput(tester);

    await tester.tap(find.text('Standort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standort verwenden'));
    await tester.pumpAndSettle();

    expect(locationService.requestCount, 1);
    expect(weatherService.fetchCount, 0);
    expect(
      find.text(
        'Standortfreigabe wurde abgelehnt. Du kannst stattdessen einen Ort suchen.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Ort suchen'), findsOneWidget);
    expect(find.text('Manuelle Eingabe'), findsOneWidget);
  });

  testWidgets('weather errors fall back to manual input', (tester) async {
    final weatherService = _FakeWeatherService(
      searchError: const WeatherServiceException('Ort nicht gefunden.'),
    );
    await _pumpCalculator(tester, weatherService: weatherService);
    await _expandInput(tester);

    await tester.tap(find.text('Ort'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ort suchen'), 'xx');
    await tester.tap(find.text('Wetter laden'));
    await tester.pumpAndSettle();

    expect(find.text('Ort nicht gefunden.'), findsOneWidget);
    expect(find.text('Manuelle Eingabe'), findsOneWidget);
    expect(find.text('21,0 °C'), findsOneWidget);
  });

  testWidgets('weather fetch errors fall back after successful place search', (
    tester,
  ) async {
    final weatherService = _FakeWeatherService(
      fetchError: const WeatherServiceException(
        'Wetterdienst antwortet mit Status 500.',
      ),
    );
    await _pumpCalculator(tester, weatherService: weatherService);
    await _expandInput(tester);

    await tester.tap(find.text('Ort'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ort suchen'), 'HH');
    await tester.tap(find.text('Wetter laden'));
    await tester.pumpAndSettle();

    expect(weatherService.searchCount, 1);
    expect(weatherService.fetchCount, 1);
    expect(find.text('Wetterdienst antwortet mit Status 500.'), findsOneWidget);
    expect(find.text('Manuelle Eingabe'), findsOneWidget);
    expect(find.text('21,0 °C'), findsOneWidget);
  });

  testWidgets('restores manual values and detail preference locally', (
    tester,
  ) async {
    await _pumpCalculator(
      tester,
      initialPreferences: const CalculatorPreferences(
        inputMode: 'manual',
        detailMode: 'pro',
        manualTemperatureText: '19,5',
        manualHumidityText: '75',
        manualPressureText: '990,5',
        isInputExpanded: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('19,5 °C'), findsOneWidget);
    expect(find.text('75,0 %'), findsOneWidget);
    expect(find.text('990,50 hPa'), findsOneWidget);
    expect(find.text('Absolute Feuchte'), findsOneWidget);
  });

  testWidgets('restores saved weather without startup network request', (
    tester,
  ) async {
    const selectedPlace = WeatherPlace(
      name: 'Hamburg',
      country: 'Deutschland',
      admin1: 'Hamburg',
      coordinates: WeatherCoordinates(latitude: 53.55, longitude: 9.99),
    );
    final weatherService = _FakeWeatherService();

    await _pumpCalculator(
      tester,
      weatherService: weatherService,
      initialPreferences: CalculatorPreferences(
        inputMode: 'place',
        detailMode: 'simple',
        manualTemperatureText: '21.0',
        manualHumidityText: '50',
        manualPressureText: '',
        isInputExpanded: true,
        placeQuery: 'Hamburg',
        selectedPlace: selectedPlace,
        measurement: _measurement(label: 'Hamburg, Hamburg'),
      ),
    );
    await tester.pumpAndSettle();

    expect(weatherService.searchCount, 0);
    expect(weatherService.fetchCount, 0);
    expect(find.text('Hamburg, Hamburg'), findsOneWidget);
    expect(
      find.text('Gespeicherte Wetterwerte vom letzten Abruf.'),
      findsOneWidget,
    );
    expect(find.text('Aktualisieren'), findsOneWidget);
  });

  testWidgets(
    'restores saved location values without startup location request',
    (tester) async {
      final weatherService = _FakeWeatherService();
      final locationService = _FakeLocationService();

      await _pumpCalculator(
        tester,
        weatherService: weatherService,
        locationService: locationService,
        initialPreferences: CalculatorPreferences(
          inputMode: 'location',
          detailMode: 'simple',
          manualTemperatureText: '21.0',
          manualHumidityText: '50',
          manualPressureText: '',
          isInputExpanded: true,
          measurement: _measurement(
            label: 'Aktueller Standort',
            source: MeasurementSource.location,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(locationService.requestCount, 0);
      expect(weatherService.fetchCount, 0);
      expect(find.text('Aktueller Standort'), findsOneWidget);
      expect(find.text('Aktualisieren'), findsNothing);
    },
  );

  testWidgets('saves changed manual inputs through the preferences store', (
    tester,
  ) async {
    final store = await _pumpCalculator(tester);
    await _expandInput(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Temperatur'),
      '18,4',
    );
    await tester.pumpAndSettle();

    expect(store.saved?.inputMode, 'manual');
    expect(store.saved?.manualTemperatureText, '18,4');
    expect(store.saved?.manualHumidityText, '50');
  });

  testWidgets('chart drag applies rounded manual values', (tester) async {
    await _pumpCalculator(tester);

    await _dragChartPoint(
      tester,
      fromTemperature: 21,
      fromHumidity: 50,
      toTemperature: 24,
      toHumidity: 65,
    );

    expect(find.text('24,0 °C'), findsOneWidget);
    expect(find.text('65,0 %'), findsOneWidget);
    expect(find.text('manuell · Manuelle Eingabe'), findsOneWidget);
  });

  testWidgets('curve lock drags the point along the existing humidity curve', (
    tester,
  ) async {
    await _pumpCalculator(tester);

    await tester.tap(find.byKey(const ValueKey('chart-curve-lock-button')));
    await tester.pumpAndSettle();
    await _dragChartPoint(
      tester,
      fromTemperature: 21,
      fromHumidity: 50,
      toTemperature: 25,
      toHumidity: 50,
    );

    final lockedHumidity = Psychrometrics.relativeHumidityForAbsoluteHumidity(
      temperatureCelsius: 25,
      absoluteHumidityGM3: Psychrometrics.calculate(
        const PsychrometricInput(
          temperatureCelsius: 21,
          relativeHumidityPercent: 50,
        ),
      ).absoluteHumidityGM3,
    ).round();

    expect(find.text('25,0 °C'), findsOneWidget);
    expect(find.text('$lockedHumidity,0 %'), findsOneWidget);
  });

  testWidgets('chart wheel zoom enables reset view button', (tester) async {
    await _pumpCalculator(tester);

    final resetButton = find.byKey(const ValueKey('chart-reset-view-button'));
    expect(tester.widget<IconButton>(resetButton).onPressed, isNull);

    final chart = find.byKey(const ValueKey('humidity-curve-chart'));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(chart),
        scrollDelta: const Offset(0, -120),
      ),
    );
    await tester.pump();

    expect(tester.widget<IconButton>(resetButton).onPressed, isNotNull);
    await tester.tap(resetButton);
    await tester.pump();

    expect(tester.widget<IconButton>(resetButton).onPressed, isNull);
  });

  testWidgets('expanded calculator controls fit on small displays', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpCalculator(tester);
    expect(tester.takeException(), isNull);

    await _expandInput(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Manuelle Werte'), findsOneWidget);

    await tester.ensureVisible(find.text('Standort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standort'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Standort verwenden'), findsOneWidget);
  });
}

Future<void> _expandInput(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('compact-input-row')));
  await tester.pumpAndSettle();
}

Future<_FakePreferencesStore> _pumpCalculator(
  WidgetTester tester, {
  WeatherService? weatherService,
  LocationService? locationService,
  CalculatorPreferences? initialPreferences,
}) async {
  final preferencesStore = _FakePreferencesStore(initialPreferences);
  await tester.pumpWidget(
    DewprofiApp(
      weatherService: weatherService,
      locationService: locationService,
      preferencesStore: preferencesStore,
    ),
  );
  await tester.pump();
  return preferencesStore;
}

Future<void> _switchToProMode(WidgetTester tester) async {
  final proMode = find.text('Profi');
  await tester.ensureVisible(proMode);
  await tester.pumpAndSettle();
  await tester.tap(proMode);
  await tester.pumpAndSettle();
}

Future<void> _dragChartPoint(
  WidgetTester tester, {
  required double fromTemperature,
  required double fromHumidity,
  required double toTemperature,
  required double toHumidity,
}) async {
  final chart = find.byKey(const ValueKey('humidity-curve-chart'));
  final result = Psychrometrics.calculate(
    PsychrometricInput(
      temperatureCelsius: fromTemperature,
      relativeHumidityPercent: fromHumidity,
    ),
  );
  final start = _chartPosition(
    tester,
    chart,
    result: result,
    temperature: fromTemperature,
    humidity: fromHumidity,
  );
  final end = _chartPosition(
    tester,
    chart,
    result: result,
    temperature: toTemperature,
    humidity: toHumidity,
  );

  await tester.dragFrom(start, end - start);
  await tester.pumpAndSettle();
}

Offset _chartPosition(
  WidgetTester tester,
  Finder chart, {
  required PsychrometricResult result,
  required double temperature,
  required double humidity,
}) {
  final topLeft = tester.getTopLeft(chart);
  final size = tester.getSize(chart);
  final plotRect = Rect.fromLTWH(
    44,
    14,
    math.max(1, size.width - 64),
    math.max(1, size.height - 50),
  );
  final dewPoint = result.dewPointCelsius;
  final minTemperature = math
      .min(
        result.temperatureCelsius - 8,
        (dewPoint ?? result.temperatureCelsius) - 4,
      )
      .floorToDouble();
  final maxTemperature = math
      .max(result.temperatureCelsius + 14, result.temperatureCelsius + 4)
      .ceilToDouble();
  final x =
      plotRect.left +
      (temperature - minTemperature) /
          (maxTemperature - minTemperature) *
          plotRect.width;
  final y = plotRect.bottom - humidity / 100 * plotRect.height;

  return topLeft + Offset(x, y);
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
  _FakeWeatherService({
    WeatherMeasurement? measurement,
    Object? error,
    Object? searchError,
    Object? fetchError,
  }) : measurement = measurement ?? _measurement(),
       searchError = searchError ?? error,
       fetchError = fetchError ?? error;

  final WeatherMeasurement measurement;
  final Object? searchError;
  final Object? fetchError;
  String? lastSearchQuery;
  WeatherCoordinates? lastCoordinates;
  int searchCount = 0;
  int fetchCount = 0;

  @override
  Future<List<WeatherPlace>> searchPlaces(String query) async {
    searchCount += 1;
    lastSearchQuery = query;
    final error = searchError;
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
    fetchCount += 1;
    lastCoordinates = coordinates;
    final error = fetchError;
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

class _FakeLocationService implements LocationService {
  _FakeLocationService({
    this.coordinates = const WeatherCoordinates(
      latitude: 53.55,
      longitude: 9.99,
    ),
    this.error,
  });

  final WeatherCoordinates coordinates;
  final Object? error;
  int requestCount = 0;

  @override
  Future<WeatherCoordinates> currentCoordinates() async {
    requestCount += 1;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return coordinates;
  }
}

class _FakePreferencesStore implements CalculatorPreferencesStore {
  _FakePreferencesStore(this.initial);

  final CalculatorPreferences? initial;
  CalculatorPreferences? saved;

  @override
  Future<CalculatorPreferences?> load() async => initial;

  @override
  Future<void> save(CalculatorPreferences preferences) async {
    saved = preferences;
  }
}
