import 'dart:math' as math;

const double defaultAtmosphericPressureHPa = 1013.25;

enum HumidityZone {
  dry('trocken'),
  comfortable('angenehm'),
  humid('feucht'),
  critical('kritisch');

  const HumidityZone(this.label);

  final String label;
}

class PsychrometricInput {
  const PsychrometricInput({
    required this.temperatureCelsius,
    required this.relativeHumidityPercent,
    double? pressureHPa,
  }) : pressureHPa = pressureHPa ?? defaultAtmosphericPressureHPa;

  final double temperatureCelsius;
  final double relativeHumidityPercent;
  final double pressureHPa;
}

class PsychrometricResult {
  const PsychrometricResult({
    required this.temperatureCelsius,
    required this.relativeHumidityPercent,
    required this.pressureHPa,
    required this.saturationVaporPressureHPa,
    required this.vaporPressureHPa,
    required this.absoluteHumidityGM3,
    required this.dewPointCelsius,
    required this.zone,
  });

  final double temperatureCelsius;
  final double relativeHumidityPercent;
  final double pressureHPa;
  final double saturationVaporPressureHPa;
  final double vaporPressureHPa;
  final double absoluteHumidityGM3;
  final double? dewPointCelsius;
  final HumidityZone zone;

  double get dewPointSpreadCelsius {
    final dewPoint = dewPointCelsius;
    if (dewPoint == null) {
      return double.infinity;
    }
    return temperatureCelsius - dewPoint;
  }
}

class Psychrometrics {
  const Psychrometrics._();

  static PsychrometricResult calculate(PsychrometricInput input) {
    _validate(input);

    final saturationVaporPressure = saturationVaporPressureHPa(
      input.temperatureCelsius,
    );
    final vaporPressure =
        saturationVaporPressure * input.relativeHumidityPercent / 100;
    final dewPoint = input.relativeHumidityPercent == 0
        ? null
        : dewPointCelsius(
            temperatureCelsius: input.temperatureCelsius,
            relativeHumidityPercent: input.relativeHumidityPercent,
          );
    final absoluteHumidity = absoluteHumidityGM3(
      temperatureCelsius: input.temperatureCelsius,
      vaporPressureHPa: vaporPressure,
    );

    return PsychrometricResult(
      temperatureCelsius: input.temperatureCelsius,
      relativeHumidityPercent: input.relativeHumidityPercent,
      pressureHPa: input.pressureHPa,
      saturationVaporPressureHPa: saturationVaporPressure,
      vaporPressureHPa: vaporPressure,
      absoluteHumidityGM3: absoluteHumidity,
      dewPointCelsius: dewPoint,
      zone: classify(
        temperatureCelsius: input.temperatureCelsius,
        relativeHumidityPercent: input.relativeHumidityPercent,
        dewPointCelsius: dewPoint,
      ),
    );
  }

  static double saturationVaporPressureHPa(double temperatureCelsius) {
    final constants = _magnusConstantsFor(temperatureCelsius);
    return constants.baseHPa *
        math.exp(
          constants.a *
              temperatureCelsius /
              (constants.bCelsius + temperatureCelsius),
        );
  }

  static double dewPointCelsius({
    required double temperatureCelsius,
    required double relativeHumidityPercent,
  }) {
    if (relativeHumidityPercent <= 0) {
      throw ArgumentError.value(
        relativeHumidityPercent,
        'relativeHumidityPercent',
        'must be greater than 0 for dew point calculation',
      );
    }
    if (relativeHumidityPercent > 100) {
      throw ArgumentError.value(
        relativeHumidityPercent,
        'relativeHumidityPercent',
        'must be at most 100',
      );
    }

    final constants = _magnusConstantsFor(temperatureCelsius);
    final gamma =
        math.log(relativeHumidityPercent / 100) +
        constants.a *
            temperatureCelsius /
            (constants.bCelsius + temperatureCelsius);
    return constants.bCelsius * gamma / (constants.a - gamma);
  }

  static double absoluteHumidityGM3({
    required double temperatureCelsius,
    required double vaporPressureHPa,
  }) {
    final kelvin = temperatureCelsius + 273.15;
    return 216.7 * vaporPressureHPa / kelvin;
  }

  static double relativeHumidityForAbsoluteHumidity({
    required double temperatureCelsius,
    required double absoluteHumidityGM3,
  }) {
    final vaporPressureHPa =
        absoluteHumidityGM3 * (temperatureCelsius + 273.15) / 216.7;
    final saturation = saturationVaporPressureHPa(temperatureCelsius);
    return vaporPressureHPa / saturation * 100;
  }

  static HumidityZone classify({
    required double temperatureCelsius,
    required double relativeHumidityPercent,
    required double? dewPointCelsius,
  }) {
    final dewPointSpread = dewPointCelsius == null
        ? double.infinity
        : temperatureCelsius - dewPointCelsius;

    if (relativeHumidityPercent >= 70 || dewPointSpread <= 2) {
      return HumidityZone.critical;
    }
    if (relativeHumidityPercent >= 60) {
      return HumidityZone.humid;
    }
    if (relativeHumidityPercent < 40) {
      return HumidityZone.dry;
    }
    return HumidityZone.comfortable;
  }

  static void _validate(PsychrometricInput input) {
    if (!input.temperatureCelsius.isFinite ||
        input.temperatureCelsius < -80 ||
        input.temperatureCelsius > 80) {
      throw ArgumentError.value(
        input.temperatureCelsius,
        'temperatureCelsius',
        'must be between -80 and 80',
      );
    }
    if (!input.relativeHumidityPercent.isFinite ||
        input.relativeHumidityPercent < 0 ||
        input.relativeHumidityPercent > 100) {
      throw ArgumentError.value(
        input.relativeHumidityPercent,
        'relativeHumidityPercent',
        'must be between 0 and 100',
      );
    }
    if (!input.pressureHPa.isFinite ||
        input.pressureHPa < 300 ||
        input.pressureHPa > 1100) {
      throw ArgumentError.value(
        input.pressureHPa,
        'pressureHPa',
        'must be between 300 and 1100 hPa',
      );
    }
  }

  static _MagnusConstants _magnusConstantsFor(double temperatureCelsius) {
    if (temperatureCelsius < 0) {
      return const _MagnusConstants(a: 22.46, bCelsius: 272.62, baseHPa: 6.112);
    }
    return const _MagnusConstants(a: 17.62, bCelsius: 243.12, baseHPa: 6.112);
  }
}

class _MagnusConstants {
  const _MagnusConstants({
    required this.a,
    required this.bCelsius,
    required this.baseHPa,
  });

  final double a;
  final double bCelsius;
  final double baseHPa;
}
