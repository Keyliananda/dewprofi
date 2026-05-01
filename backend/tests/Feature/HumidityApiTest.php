<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class HumidityApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_psychrometrics_endpoint_calculates_core_values(): void
    {
        $this->postJson('/api/psychrometrics', [
            'temperatureCelsius' => 21,
            'relativeHumidityPercent' => 50,
        ])
            ->assertOk()
            ->assertJsonPath('result.temperatureCelsius', 21)
            ->assertJsonPath('result.relativeHumidityPercent', 50)
            ->assertJsonPath('result.pressureHPa', 1013.25)
            ->assertJsonPath('result.zone', 'angenehm')
            ->assertJson(fn ($json) => $json
                ->where('result.dewPointCelsius', fn ($value) => abs($value - 10.2) < 0.3)
                ->where('result.absoluteHumidityGM3', fn ($value) => abs($value - 9.2) < 0.3)
                ->etc());
    }

    public function test_example_places_are_available(): void
    {
        $this->getJson('/api/example-places')
            ->assertOk()
            ->assertJsonPath('places.0.name', 'Hamburg')
            ->assertJsonPath('places.1.name', 'Berlin')
            ->assertJsonPath('places.4.name', 'Muenchen');
    }

    public function test_place_search_maps_open_meteo_results(): void
    {
        Http::fake([
            'geocoding-api.open-meteo.com/*' => Http::response([
                'results' => [[
                    'name' => 'Hamburg',
                    'country' => 'Deutschland',
                    'admin1' => 'Hamburg',
                    'latitude' => 53.55,
                    'longitude' => 9.99,
                ]],
            ]),
        ]);

        $this->getJson('/api/places?query=Hamburg')
            ->assertOk()
            ->assertJsonPath('places.0.displayName', 'Hamburg, Hamburg')
            ->assertJsonPath('places.0.coordinates.latitude', 53.55);
    }

    public function test_weather_endpoint_returns_measurement_and_result(): void
    {
        Http::fake([
            'api.open-meteo.com/*' => Http::response([
                'current' => [
                    'time' => '2026-05-01T12:00',
                    'temperature_2m' => 18,
                    'relative_humidity_2m' => 62,
                    'surface_pressure' => 1007,
                ],
            ]),
        ]);

        $this->getJson('/api/weather?latitude=53.55&longitude=9.99&label=Hamburg%2C%20Hamburg&source=place')
            ->assertOk()
            ->assertJsonPath('measurement.label', 'Hamburg, Hamburg')
            ->assertJsonPath('measurement.source', 'place')
            ->assertJsonPath('measurement.temperatureCelsius', 18)
            ->assertJsonPath('measurement.relativeHumidityPercent', 62)
            ->assertJsonPath('measurement.pressureHPa', 1007)
            ->assertJsonPath('result.zone', 'feucht');
    }
}
