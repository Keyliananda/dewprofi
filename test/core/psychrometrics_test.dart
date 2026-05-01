import 'package:dewprofi/core/psychrometrics/psychrometrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Psychrometrics.calculate', () {
    test('uses the default pressure when none is supplied', () {
      const input = PsychrometricInput(
        temperatureCelsius: 20,
        relativeHumidityPercent: 50,
      );

      final result = Psychrometrics.calculate(input);

      expect(result.pressureHPa, defaultAtmosphericPressureHPa);
    });

    test('calculates plausible values for a typical living room', () {
      const input = PsychrometricInput(
        temperatureCelsius: 20,
        relativeHumidityPercent: 50,
      );

      final result = Psychrometrics.calculate(input);

      expect(result.dewPointCelsius, closeTo(9.3, 0.2));
      expect(result.absoluteHumidityGM3, closeTo(8.6, 0.2));
      expect(result.zone, HumidityZone.comfortable);
    });

    test('handles 0 percent relative humidity', () {
      const input = PsychrometricInput(
        temperatureCelsius: 21,
        relativeHumidityPercent: 0,
      );

      final result = Psychrometrics.calculate(input);

      expect(result.dewPointCelsius, isNull);
      expect(result.absoluteHumidityGM3, 0);
      expect(result.zone, HumidityZone.dry);
    });

    test('handles 100 percent relative humidity', () {
      const input = PsychrometricInput(
        temperatureCelsius: 12,
        relativeHumidityPercent: 100,
      );

      final result = Psychrometrics.calculate(input);

      expect(result.dewPointCelsius, closeTo(12, 0.01));
      expect(result.zone, HumidityZone.critical);
    });

    test('handles negative temperatures', () {
      const input = PsychrometricInput(
        temperatureCelsius: -5,
        relativeHumidityPercent: 80,
      );

      final result = Psychrometrics.calculate(input);

      expect(result.dewPointCelsius, lessThan(-5));
      expect(result.dewPointCelsius, closeTo(-7.7, 0.3));
      expect(result.absoluteHumidityGM3, greaterThan(0));
    });

    test('rejects relative humidity outside 0 to 100 percent', () {
      const input = PsychrometricInput(
        temperatureCelsius: 20,
        relativeHumidityPercent: 101,
      );

      expect(
        () => Psychrometrics.calculate(input),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts a supplied plausible pressure', () {
      const input = PsychrometricInput(
        temperatureCelsius: 18,
        relativeHumidityPercent: 45,
        pressureHPa: 850,
      );

      final result = Psychrometrics.calculate(input);

      expect(result.pressureHPa, 850);
      expect(result.absoluteHumidityGM3, greaterThan(0));
    });
  });

  group('Psychrometrics.relativeHumidityForAbsoluteHumidity', () {
    test('returns the original humidity at the original temperature', () {
      final result = Psychrometrics.calculate(
        const PsychrometricInput(
          temperatureCelsius: 22,
          relativeHumidityPercent: 55,
        ),
      );

      final relativeHumidity =
          Psychrometrics.relativeHumidityForAbsoluteHumidity(
            temperatureCelsius: result.temperatureCelsius,
            absoluteHumidityGM3: result.absoluteHumidityGM3,
          );

      expect(relativeHumidity, closeTo(55, 0.1));
    });
  });
}
