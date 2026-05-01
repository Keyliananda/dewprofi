import 'package:dewprofi/features/weather/weather_measurement.dart';
import 'package:dewprofi/features/weather/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenMeteoWeatherService', () {
    test('searchPlaces parses geocoding results', () async {
      final service = OpenMeteoWeatherService(
        client: MockClient((request) async {
          expect(request.url.host, 'geocoding-api.open-meteo.com');
          expect(request.url.queryParameters['name'], 'Berlin');
          return http.Response('''
            {
              "results": [
                {
                  "name": "Berlin",
                  "country": "Deutschland",
                  "admin1": "Berlin",
                  "latitude": 52.52,
                  "longitude": 13.405
                }
              ]
            }
            ''', 200);
        }),
      );

      final places = await service.searchPlaces('Berlin');

      expect(places, hasLength(1));
      expect(places.single.displayName, 'Berlin, Berlin');
      expect(places.single.coordinates.latitude, 52.52);
    });

    test('fetchWeather parses current weather with pressure', () async {
      final service = OpenMeteoWeatherService(
        client: MockClient((request) async {
          expect(request.url.host, 'api.open-meteo.com');
          expect(
            request.url.queryParameters['current'],
            contains('relative_humidity_2m'),
          );
          return http.Response('''
            {
              "current": {
                "time": "2026-05-01T10:00",
                "temperature_2m": 17.4,
                "relative_humidity_2m": 63,
                "surface_pressure": 1008.2
              }
            }
            ''', 200);
        }),
      );

      final measurement = await service.fetchWeather(
        coordinates: const WeatherCoordinates(latitude: 52.52, longitude: 13.4),
        source: MeasurementSource.place,
        label: 'Berlin, Berlin',
      );

      expect(measurement.label, 'Berlin, Berlin');
      expect(measurement.source, MeasurementSource.place);
      expect(measurement.temperatureCelsius, 17.4);
      expect(measurement.relativeHumidityPercent, 63);
      expect(measurement.pressureHPa, 1008.2);
    });

    test('fetchWeather rejects missing humidity', () async {
      final service = OpenMeteoWeatherService(
        client: MockClient(
          (_) async =>
              http.Response('{"current": {"temperature_2m": 17.4}}', 200),
        ),
      );

      await expectLater(
        service.fetchWeather(
          coordinates: const WeatherCoordinates(
            latitude: 52.52,
            longitude: 13.4,
          ),
          source: MeasurementSource.place,
          label: 'Berlin',
        ),
        throwsA(isA<WeatherServiceException>()),
      );
    });

    test('fetchWeather reports http failures', () async {
      final service = OpenMeteoWeatherService(
        client: MockClient(
          (_) async => http.Response('Internal Server Error', 500),
        ),
      );

      await expectLater(
        service.fetchWeather(
          coordinates: const WeatherCoordinates(
            latitude: 52.52,
            longitude: 13.4,
          ),
          source: MeasurementSource.place,
          label: 'Berlin',
        ),
        throwsA(
          isA<WeatherServiceException>().having(
            (error) => error.message,
            'message',
            'Wetterdienst antwortet mit Status 500.',
          ),
        ),
      );
    });

    test('searchPlaces reports malformed responses', () async {
      final service = OpenMeteoWeatherService(
        client: MockClient((_) async => http.Response('not json', 200)),
      );

      await expectLater(
        service.searchPlaces('Berlin'),
        throwsA(
          isA<WeatherServiceException>().having(
            (error) => error.message,
            'message',
            'Unerwartete Antwort vom Wetterdienst.',
          ),
        ),
      );
    });

    test('searchPlaces reports unknown places', () async {
      final service = OpenMeteoWeatherService(
        client: MockClient((_) async => http.Response('{"results": []}', 200)),
      );

      await expectLater(
        service.searchPlaces('KeinOrt'),
        throwsA(isA<WeatherServiceException>()),
      );
    });
  });
}
