import 'package:flutter/material.dart';

import '../core/storage/calculator_preferences_store.dart';
import '../features/humidity_calculator/humidity_calculator_page.dart';
import '../features/location/location_service.dart';
import '../features/sensors/ble_advertisement_scanner.dart';
import '../features/weather/weather_service.dart';

class DewprofiApp extends StatelessWidget {
  const DewprofiApp({
    super.key,
    this.weatherService,
    this.preferencesStore,
    this.locationService,
    this.goveeScanner,
  });

  final WeatherService? weatherService;
  final CalculatorPreferencesStore? preferencesStore;
  final LocationService? locationService;
  final BleAdvertisementScanner? goveeScanner;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E);

    return MaterialApp(
      title: 'Dewprofi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          primary: seed,
          secondary: const Color(0xFFB45309),
          tertiary: const Color(0xFF4F46E5),
          surface: const Color(0xFFFFFBF5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F3EF),
        visualDensity: VisualDensity.standard,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          filled: true,
          fillColor: Color(0xFFFFFBF5),
        ),
      ),
      home: HumidityCalculatorPage(
        weatherService: weatherService,
        preferencesStore: preferencesStore,
        locationService: locationService,
        goveeScanner: goveeScanner,
      ),
    );
  }
}
