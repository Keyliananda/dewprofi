import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/weather/weather_measurement.dart';

class CalculatorPreferences {
  const CalculatorPreferences({
    required this.inputMode,
    required this.detailMode,
    required this.manualTemperatureText,
    required this.manualHumidityText,
    required this.manualPressureText,
    required this.isInputExpanded,
    this.placeQuery,
    this.selectedPlace,
    this.measurement,
  });

  final String inputMode;
  final String detailMode;
  final String manualTemperatureText;
  final String manualHumidityText;
  final String manualPressureText;
  final bool isInputExpanded;
  final String? placeQuery;
  final WeatherPlace? selectedPlace;
  final WeatherMeasurement? measurement;

  Map<String, Object?> toJson() {
    return {
      'version': 1,
      'inputMode': inputMode,
      'detailMode': detailMode,
      'manualTemperatureText': manualTemperatureText,
      'manualHumidityText': manualHumidityText,
      'manualPressureText': manualPressureText,
      'isInputExpanded': isInputExpanded,
      'placeQuery': placeQuery,
      'selectedPlace': selectedPlace == null
          ? null
          : _placeToJson(selectedPlace!),
      'measurement': measurement == null
          ? null
          : _measurementToJson(measurement!),
    };
  }

  static CalculatorPreferences? fromJson(Map<String, Object?> json) {
    final inputMode = json['inputMode'];
    final detailMode = json['detailMode'];
    final manualTemperatureText = json['manualTemperatureText'];
    final manualHumidityText = json['manualHumidityText'];
    final manualPressureText = json['manualPressureText'];
    final isInputExpanded = json['isInputExpanded'];

    if (inputMode is! String ||
        detailMode is! String ||
        manualTemperatureText is! String ||
        manualHumidityText is! String ||
        manualPressureText is! String ||
        isInputExpanded is! bool) {
      return null;
    }

    final selectedPlaceJson = _readObjectMap(json['selectedPlace']);
    final measurementJson = _readObjectMap(json['measurement']);

    return CalculatorPreferences(
      inputMode: inputMode,
      detailMode: detailMode,
      manualTemperatureText: manualTemperatureText,
      manualHumidityText: manualHumidityText,
      manualPressureText: manualPressureText,
      isInputExpanded: isInputExpanded,
      placeQuery: json['placeQuery'] is String
          ? json['placeQuery']! as String
          : null,
      selectedPlace: selectedPlaceJson == null
          ? null
          : _placeFromJson(selectedPlaceJson),
      measurement: measurementJson == null
          ? null
          : _measurementFromJson(measurementJson),
    );
  }
}

abstract class CalculatorPreferencesStore {
  Future<CalculatorPreferences?> load();

  Future<void> save(CalculatorPreferences preferences);
}

class SharedPreferencesCalculatorPreferencesStore
    implements CalculatorPreferencesStore {
  const SharedPreferencesCalculatorPreferencesStore();

  static const _key = 'dewprofi.calculator.preferences.v1';

  @override
  Future<CalculatorPreferences?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key);
    if (value == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return null;
      }
      return CalculatorPreferences.fromJson(decoded.cast<String, Object?>());
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(CalculatorPreferences preferences) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString(_key, jsonEncode(preferences.toJson()));
  }
}

Map<String, Object?> _measurementToJson(WeatherMeasurement measurement) {
  return {
    'temperatureCelsius': measurement.temperatureCelsius,
    'relativeHumidityPercent': measurement.relativeHumidityPercent,
    'pressureHPa': measurement.pressureHPa,
    'source': measurement.source.name,
    'label': measurement.label,
    'observedAt': measurement.observedAt.toIso8601String(),
    'fetchedAt': measurement.fetchedAt.toIso8601String(),
  };
}

WeatherMeasurement? _measurementFromJson(Map<String, Object?> json) {
  final temperature = _readDouble(json['temperatureCelsius']);
  final humidity = _readDouble(json['relativeHumidityPercent']);
  final source = _sourceFromName(json['source']);
  final label = json['label'];
  final observedAt = _readDateTime(json['observedAt']);
  final fetchedAt = _readDateTime(json['fetchedAt']);
  if (temperature == null ||
      humidity == null ||
      source == null ||
      label is! String ||
      observedAt == null ||
      fetchedAt == null) {
    return null;
  }

  return WeatherMeasurement(
    temperatureCelsius: temperature,
    relativeHumidityPercent: humidity,
    pressureHPa: _readDouble(json['pressureHPa']),
    source: source,
    label: label,
    observedAt: observedAt,
    fetchedAt: fetchedAt,
  );
}

Map<String, Object?> _placeToJson(WeatherPlace place) {
  return {
    'name': place.name,
    'country': place.country,
    'admin1': place.admin1,
    'latitude': place.coordinates.latitude,
    'longitude': place.coordinates.longitude,
  };
}

WeatherPlace? _placeFromJson(Map<String, Object?> json) {
  final name = json['name'];
  final country = json['country'];
  final latitude = _readDouble(json['latitude']);
  final longitude = _readDouble(json['longitude']);
  if (name is! String ||
      country is! String ||
      latitude == null ||
      longitude == null) {
    return null;
  }

  return WeatherPlace(
    name: name,
    country: country,
    admin1: json['admin1'] is String ? json['admin1']! as String : null,
    coordinates: WeatherCoordinates(latitude: latitude, longitude: longitude),
  );
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

Map<String, Object?>? _readObjectMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.cast<String, Object?>();
}

DateTime? _readDateTime(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value);
}

MeasurementSource? _sourceFromName(Object? value) {
  if (value is! String) {
    return null;
  }
  for (final source in MeasurementSource.values) {
    if (source.name == value) {
      return source;
    }
  }
  return null;
}
