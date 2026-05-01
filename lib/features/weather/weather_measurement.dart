import '../../core/psychrometrics/psychrometrics.dart';

enum MeasurementSource {
  manual('manuell'),
  place('ort'),
  examplePlace('beispielort'),
  location('standort');

  const MeasurementSource(this.label);

  final String label;
}

class WeatherMeasurement {
  const WeatherMeasurement({
    required this.temperatureCelsius,
    required this.relativeHumidityPercent,
    required this.source,
    required this.label,
    required this.observedAt,
    required this.fetchedAt,
    this.pressureHPa,
  });

  final double temperatureCelsius;
  final double relativeHumidityPercent;
  final double? pressureHPa;
  final MeasurementSource source;
  final String label;
  final DateTime observedAt;
  final DateTime fetchedAt;

  Duration ageAt(DateTime now) => now.difference(observedAt);

  PsychrometricInput toPsychrometricInput() {
    return PsychrometricInput(
      temperatureCelsius: temperatureCelsius,
      relativeHumidityPercent: relativeHumidityPercent,
      pressureHPa: pressureHPa,
    );
  }
}

class WeatherCoordinates {
  const WeatherCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class WeatherPlace {
  const WeatherPlace({
    required this.name,
    required this.country,
    required this.coordinates,
    this.admin1,
  });

  final String name;
  final String country;
  final String? admin1;
  final WeatherCoordinates coordinates;

  String get displayName {
    final region = admin1;
    if (region == null || region.isEmpty) {
      return '$name, $country';
    }
    return '$name, $region';
  }
}
