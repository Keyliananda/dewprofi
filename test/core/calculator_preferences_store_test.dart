import 'package:dewprofi/core/storage/calculator_preferences_store.dart';
import 'package:dewprofi/features/weather/weather_measurement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'SharedPreferencesCalculatorPreferencesStore saves and loads state',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesCalculatorPreferencesStore();
      final observedAt = DateTime(2026, 5, 1, 10);

      await store.save(
        CalculatorPreferences(
          inputMode: 'place',
          detailMode: 'pro',
          manualTemperatureText: '19,5',
          manualHumidityText: '64',
          manualPressureText: '1008',
          isInputExpanded: true,
          placeQuery: 'Hamburg',
          selectedPlace: const WeatherPlace(
            name: 'Hamburg',
            country: 'Deutschland',
            admin1: 'Hamburg',
            coordinates: WeatherCoordinates(latitude: 53.55, longitude: 9.99),
          ),
          measurement: WeatherMeasurement(
            temperatureCelsius: 18,
            relativeHumidityPercent: 62,
            pressureHPa: 1007,
            source: MeasurementSource.place,
            label: 'Hamburg, Hamburg',
            observedAt: observedAt,
            fetchedAt: observedAt.add(const Duration(minutes: 1)),
          ),
        ),
      );

      final loaded = await store.load();

      expect(loaded?.inputMode, 'place');
      expect(loaded?.detailMode, 'pro');
      expect(loaded?.manualTemperatureText, '19,5');
      expect(loaded?.selectedPlace?.displayName, 'Hamburg, Hamburg');
      expect(loaded?.measurement?.label, 'Hamburg, Hamburg');
      expect(loaded?.measurement?.source, MeasurementSource.place);
      expect(
        loaded?.measurement?.fetchedAt,
        observedAt.add(const Duration(minutes: 1)),
      );
    },
  );

  test('CalculatorPreferences rejects incomplete json', () {
    expect(CalculatorPreferences.fromJson({'inputMode': 'manual'}), isNull);
  });
}
