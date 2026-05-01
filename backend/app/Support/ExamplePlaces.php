<?php

namespace App\Support;

class ExamplePlaces
{
    public static function all(): array
    {
        return [
            self::place('Hamburg', 'Deutschland', 'Hamburg', 53.5507, 9.993),
            self::place('Berlin', 'Deutschland', 'Berlin', 52.52, 13.405),
            self::place('Koeln', 'Deutschland', 'Nordrhein-Westfalen', 50.9375, 6.9603),
            self::place('Frankfurt am Main', 'Deutschland', 'Hessen', 50.1109, 8.6821),
            self::place('Muenchen', 'Deutschland', 'Bayern', 48.1372, 11.5755),
        ];
    }

    private static function place(
        string $name,
        string $country,
        string $admin1,
        float $latitude,
        float $longitude,
    ): array {
        return [
            'name' => $name,
            'country' => $country,
            'admin1' => $admin1,
            'displayName' => "{$name}, {$admin1}",
            'coordinates' => [
                'latitude' => $latitude,
                'longitude' => $longitude,
            ],
        ];
    }
}
