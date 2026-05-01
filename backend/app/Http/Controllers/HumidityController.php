<?php

namespace App\Http\Controllers;

use App\Support\ExamplePlaces;
use App\Support\Psychrometrics;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Http;
use InvalidArgumentException;

class HumidityController extends Controller
{
    public function calculate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'temperatureCelsius' => ['required', 'numeric', 'between:-80,80'],
            'relativeHumidityPercent' => ['required', 'numeric', 'between:0,100'],
            'pressureHPa' => ['nullable', 'numeric', 'between:300,1100'],
        ]);

        try {
            return response()->json([
                'result' => Psychrometrics::calculate(
                    (float) $validated['temperatureCelsius'],
                    (float) $validated['relativeHumidityPercent'],
                    isset($validated['pressureHPa']) ? (float) $validated['pressureHPa'] : null,
                ),
            ]);
        } catch (InvalidArgumentException $error) {
            return response()->json(['message' => $error->getMessage()], 422);
        }
    }

    public function examplePlaces(): JsonResponse
    {
        return response()->json([
            'places' => ExamplePlaces::all(),
        ]);
    }

    public function searchPlaces(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'query' => ['required', 'string', 'min:2'],
        ]);

        $response = $this->openMeteoGet(
            'https://geocoding-api.open-meteo.com/v1/search',
            [
                'name' => trim($validated['query']),
                'count' => 5,
                'language' => 'de',
                'format' => 'json',
            ],
            'Ortssuche ist gerade nicht erreichbar. Manuelle Eingabe bleibt nutzbar.',
        );

        $places = collect($response->json('results', []))
            ->filter(fn (mixed $place): bool => is_array($place))
            ->map(fn (array $place): ?array => $this->placeFromOpenMeteo($place))
            ->filter()
            ->values()
            ->all();

        if ($places === []) {
            return response()->json([
                'message' => 'Ort nicht gefunden. Bitte Schreibweise pruefen.',
            ], 404);
        }

        return response()->json(['places' => $places]);
    }

    public function weather(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'label' => ['required', 'string', 'max:160'],
            'source' => ['required', 'in:place,examplePlace'],
        ]);

        $response = $this->openMeteoGet(
            'https://api.open-meteo.com/v1/forecast',
            [
                'latitude' => round((float) $validated['latitude'], 5),
                'longitude' => round((float) $validated['longitude'], 5),
                'current' => 'temperature_2m,relative_humidity_2m,surface_pressure',
                'timezone' => 'auto',
                'forecast_days' => 1,
            ],
            'Wetterdaten konnten nicht geladen werden. Manuelle Eingabe bleibt nutzbar.',
        );

        $current = $response->json('current');
        if (! is_array($current)) {
            return response()->json(['message' => 'Wetterdaten fehlen in der Antwort.'], 502);
        }

        $temperature = Arr::get($current, 'temperature_2m');
        $humidity = Arr::get($current, 'relative_humidity_2m');

        if (! is_numeric($temperature) || ! is_numeric($humidity)) {
            return response()->json([
                'message' => 'Open-Meteo liefert gerade keine vollstaendigen Feuchtewerte.',
            ], 502);
        }

        $measurement = [
            'temperatureCelsius' => (float) $temperature,
            'relativeHumidityPercent' => (float) $humidity,
            'pressureHPa' => is_numeric(Arr::get($current, 'surface_pressure'))
                ? (float) Arr::get($current, 'surface_pressure')
                : null,
            'source' => $validated['source'],
            'sourceLabel' => $validated['source'] === 'place' ? 'ort' : 'beispielort',
            'label' => $validated['label'],
            'observedAt' => $this->observedAt(Arr::get($current, 'time')),
            'fetchedAt' => now()->toIso8601String(),
        ];

        return response()->json([
            'measurement' => $measurement,
            'result' => Psychrometrics::calculate(
                $measurement['temperatureCelsius'],
                $measurement['relativeHumidityPercent'],
                $measurement['pressureHPa'],
            ),
        ]);
    }

    private function openMeteoGet(string $url, array $query, string $message)
    {
        try {
            return Http::timeout(8)
                ->acceptJson()
                ->get($url, $query)
                ->throw();
        } catch (ConnectionException) {
            abort(response()->json(['message' => $message], 503));
        }
    }

    private function placeFromOpenMeteo(array $place): ?array
    {
        if (
            ! is_string(Arr::get($place, 'name'))
            || ! is_string(Arr::get($place, 'country'))
            || ! is_numeric(Arr::get($place, 'latitude'))
            || ! is_numeric(Arr::get($place, 'longitude'))
        ) {
            return null;
        }

        $admin1 = is_string(Arr::get($place, 'admin1')) ? Arr::get($place, 'admin1') : null;
        $name = Arr::get($place, 'name');
        $country = Arr::get($place, 'country');

        return [
            'name' => $name,
            'country' => $country,
            'admin1' => $admin1,
            'displayName' => $admin1 ? "{$name}, {$admin1}" : "{$name}, {$country}",
            'coordinates' => [
                'latitude' => (float) Arr::get($place, 'latitude'),
                'longitude' => (float) Arr::get($place, 'longitude'),
            ],
        ];
    }

    private function observedAt(mixed $value): string
    {
        if (is_string($value) && $value !== '') {
            return $value;
        }

        return now()->toIso8601String();
    }
}
