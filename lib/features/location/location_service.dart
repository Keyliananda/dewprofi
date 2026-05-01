import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../weather/weather_measurement.dart';

abstract class LocationService {
  Future<WeatherCoordinates> currentCoordinates();
}

class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({this.timeout = const Duration(seconds: 12)});

  final Duration timeout;

  @override
  Future<WeatherCoordinates> currentCoordinates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Standortdienste sind ausgeschaltet. Ortssuche oder manuelle Eingabe bleiben nutzbar.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(
        'Standortfreigabe wurde abgelehnt. Du kannst stattdessen einen Ort suchen.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Standortfreigabe ist dauerhaft deaktiviert. Ortssuche oder manuelle Eingabe bleiben nutzbar.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: timeout,
        ),
      );
      return WeatherCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const LocationServiceException(
        'Standort konnte nicht schnell genug bestimmt werden. Bitte Ortssuche oder manuelle Eingabe nutzen.',
      );
    } on LocationServiceDisabledException {
      throw const LocationServiceException(
        'Standortdienste sind ausgeschaltet. Ortssuche oder manuelle Eingabe bleiben nutzbar.',
      );
    } on PermissionDeniedException {
      throw const LocationServiceException(
        'Standortfreigabe wurde abgelehnt. Du kannst stattdessen einen Ort suchen.',
      );
    }
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
