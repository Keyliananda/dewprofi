import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'weather_measurement.dart';

abstract class WeatherService {
  Future<List<WeatherPlace>> searchPlaces(String query);

  Future<WeatherMeasurement> fetchWeather({
    required WeatherCoordinates coordinates,
    required MeasurementSource source,
    required String label,
  });

  Future<WeatherMeasurement> fetchWeatherForPlace({
    required WeatherPlace place,
    required MeasurementSource source,
  });
}

class OpenMeteoWeatherService implements WeatherService {
  OpenMeteoWeatherService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<List<WeatherPlace>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      throw const WeatherServiceException(
        'Bitte mindestens zwei Zeichen eingeben.',
      );
    }

    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': trimmed,
      'count': '5',
      'language': 'de',
      'format': 'json',
    });
    final response = await _get(uri);
    final decoded = _decodeObject(response.body);
    final results = decoded['results'];
    if (results is! List || results.isEmpty) {
      throw const WeatherServiceException(
        'Ort nicht gefunden. Bitte Schreibweise pruefen.',
      );
    }

    return results
        .whereType<Map<String, Object?>>()
        .map(_placeFromJson)
        .whereType<WeatherPlace>()
        .toList(growable: false);
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

  @override
  Future<WeatherMeasurement> fetchWeather({
    required WeatherCoordinates coordinates,
    required MeasurementSource source,
    required String label,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': coordinates.latitude.toStringAsFixed(5),
      'longitude': coordinates.longitude.toStringAsFixed(5),
      'current': 'temperature_2m,relative_humidity_2m,surface_pressure',
      'timezone': 'auto',
      'forecast_days': '1',
    });
    final response = await _get(uri);
    final decoded = _decodeObject(response.body);
    final current = decoded['current'];
    if (current is! Map<String, Object?>) {
      throw const WeatherServiceException('Wetterdaten fehlen in der Antwort.');
    }

    final temperature = _readNumber(current['temperature_2m']);
    final humidity = _readNumber(current['relative_humidity_2m']);
    if (temperature == null || humidity == null) {
      throw const WeatherServiceException(
        'Open-Meteo liefert gerade keine vollstaendigen Feuchtewerte.',
      );
    }

    final now = DateTime.now();
    final observedAt = _readTime(current['time']) ?? now;
    return WeatherMeasurement(
      temperatureCelsius: temperature,
      relativeHumidityPercent: humidity,
      pressureHPa: _readNumber(current['surface_pressure']),
      source: source,
      label: label,
      observedAt: observedAt,
      fetchedAt: now,
    );
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WeatherServiceException(
          'Wetterdienst antwortet mit Status ${response.statusCode}.',
        );
      }
      return response;
    } on TimeoutException {
      throw const WeatherServiceException(
        'Wetterdienst braucht zu lange. Manuelle Eingabe bleibt nutzbar.',
      );
    } on http.ClientException {
      throw const WeatherServiceException(
        'Wetterdienst ist nicht erreichbar. Manuelle Eingabe bleibt nutzbar.',
      );
    }
  }

  Map<String, Object?> _decodeObject(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const WeatherServiceException(
        'Unerwartete Antwort vom Wetterdienst.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const WeatherServiceException(
        'Unerwartete Antwort vom Wetterdienst.',
      );
    }
    return decoded;
  }

  WeatherPlace? _placeFromJson(Map<String, Object?> json) {
    final name = json['name'];
    final country = json['country'];
    final latitude = _readNumber(json['latitude']);
    final longitude = _readNumber(json['longitude']);
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

  double? _readNumber(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  DateTime? _readTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class WeatherServiceException implements Exception {
  const WeatherServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
