<?php

namespace App\Support;

use InvalidArgumentException;

class Psychrometrics
{
    public const DEFAULT_PRESSURE_HPA = 1013.25;

    public static function calculate(
        float $temperatureCelsius,
        float $relativeHumidityPercent,
        ?float $pressureHPa = null,
    ): array {
        $pressureHPa ??= self::DEFAULT_PRESSURE_HPA;
        self::validate($temperatureCelsius, $relativeHumidityPercent, $pressureHPa);

        $saturationVaporPressure = self::saturationVaporPressureHPa($temperatureCelsius);
        $vaporPressure = $saturationVaporPressure * $relativeHumidityPercent / 100;
        $dewPoint = $relativeHumidityPercent === 0.0
            ? null
            : self::dewPointCelsius($temperatureCelsius, $relativeHumidityPercent);
        $absoluteHumidity = self::absoluteHumidityGM3($temperatureCelsius, $vaporPressure);
        $dewPointSpread = $dewPoint === null ? null : $temperatureCelsius - $dewPoint;

        return [
            'temperatureCelsius' => $temperatureCelsius,
            'relativeHumidityPercent' => $relativeHumidityPercent,
            'pressureHPa' => $pressureHPa,
            'saturationVaporPressureHPa' => $saturationVaporPressure,
            'vaporPressureHPa' => $vaporPressure,
            'absoluteHumidityGM3' => $absoluteHumidity,
            'dewPointCelsius' => $dewPoint,
            'dewPointSpreadCelsius' => $dewPointSpread,
            'zone' => self::classify($relativeHumidityPercent, $dewPointSpread),
        ];
    }

    public static function relativeHumidityForAbsoluteHumidity(
        float $temperatureCelsius,
        float $absoluteHumidityGM3,
    ): float {
        $vaporPressureHPa = $absoluteHumidityGM3 * ($temperatureCelsius + 273.15) / 216.7;
        $saturation = self::saturationVaporPressureHPa($temperatureCelsius);

        return $vaporPressureHPa / $saturation * 100;
    }

    public static function saturationVaporPressureHPa(float $temperatureCelsius): float
    {
        $constants = self::magnusConstantsFor($temperatureCelsius);

        return 6.112 * exp(
            $constants['a'] * $temperatureCelsius / ($constants['b'] + $temperatureCelsius)
        );
    }

    private static function dewPointCelsius(
        float $temperatureCelsius,
        float $relativeHumidityPercent,
    ): float {
        $constants = self::magnusConstantsFor($temperatureCelsius);
        $gamma = log($relativeHumidityPercent / 100)
            + $constants['a'] * $temperatureCelsius / ($constants['b'] + $temperatureCelsius);

        return $constants['b'] * $gamma / ($constants['a'] - $gamma);
    }

    private static function absoluteHumidityGM3(
        float $temperatureCelsius,
        float $vaporPressureHPa,
    ): float {
        return 216.7 * $vaporPressureHPa / ($temperatureCelsius + 273.15);
    }

    private static function classify(float $relativeHumidityPercent, ?float $dewPointSpread): string
    {
        if ($relativeHumidityPercent >= 70 || ($dewPointSpread !== null && $dewPointSpread <= 2)) {
            return 'kritisch';
        }

        if ($relativeHumidityPercent >= 60) {
            return 'feucht';
        }

        if ($relativeHumidityPercent < 40) {
            return 'trocken';
        }

        return 'angenehm';
    }

    private static function validate(
        float $temperatureCelsius,
        float $relativeHumidityPercent,
        float $pressureHPa,
    ): void {
        if (! is_finite($temperatureCelsius) || $temperatureCelsius < -80 || $temperatureCelsius > 80) {
            throw new InvalidArgumentException('Temperatur muss zwischen -80 und 80 °C liegen.');
        }

        if (! is_finite($relativeHumidityPercent) || $relativeHumidityPercent < 0 || $relativeHumidityPercent > 100) {
            throw new InvalidArgumentException('Relative Feuchte muss zwischen 0 und 100 % liegen.');
        }

        if (! is_finite($pressureHPa) || $pressureHPa < 300 || $pressureHPa > 1100) {
            throw new InvalidArgumentException('Luftdruck muss zwischen 300 und 1100 hPa liegen.');
        }
    }

    /**
     * @return array{a: float, b: float}
     */
    private static function magnusConstantsFor(float $temperatureCelsius): array
    {
        if ($temperatureCelsius < 0) {
            return ['a' => 22.46, 'b' => 272.62];
        }

        return ['a' => 17.62, 'b' => 243.12];
    }
}
