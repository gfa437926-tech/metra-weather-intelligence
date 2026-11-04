import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_weather_intelligence/data/weather_service.dart';

void main() {
  test('fetchRiyadh parses current and daily values from provider', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.open-meteo.com');
      expect(request.url.queryParameters['latitude'], '24.7136');
      expect(request.url.queryParameters['longitude'], '46.6753');
      expect(request.url.queryParameters['timezone'], 'Asia/Riyadh');
      expect(request.url.queryParameters['forecast_days'], '1');
      expect(request.url.queryParameters['current'], isNotNull);
      expect(request.url.queryParameters['daily'], isNotNull);
      expect(request.url.queryParameters.containsKey('hourly'), isFalse,
          reason: 'Hourly forecast is fetched separately to avoid duplicate payloads.');
      return http.Response(jsonEncode({
        'current': {
          'temperature_2m': 30,
          'apparent_temperature': 32,
          'relative_humidity_2m': 40,
          'wind_speed_10m': 12,
          'surface_pressure': 1009,
          'weather_code': 1,
        },
        'daily': {
          'temperature_2m_max': [35],
          'temperature_2m_min': [22],
        },
      }), 200);
    });
    final result = await WeatherService(client: client).fetchRiyadh();
    expect(result.temperature, 30);
    expect(result.maxTemperature, 35);
    expect(result.condition, 'غائم جزئياً');
    client.close();
  });

  test('fetchHourlyRiyadh parses aligned hourly values', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({
      'hourly': {
        'time': ['2026-11-03T10:00', '2026-11-03T11:00'],
        'temperature_2m': [27, 28.5],
        'weather_code': [0, 2],
      },
    }), 200));
    final result = await WeatherService(client: client).fetchHourlyRiyadh();
    expect(result, hasLength(2));
    expect(result.last.temperature, 28.5);
    expect(result.first.symbol, '☀');
    client.close();
  });

  test('rejects non-finite hourly temperatures and invalid weather codes', () async {
    for (final payload in [
      {'time': ['2026-11-03T10:00'], 'temperature_2m': ['NaN'], 'weather_code': [0]},
      {'time': ['2026-11-03T10:00'], 'temperature_2m': [27], 'weather_code': [100]},
      {'time': ['2026-11-03T10:00'], 'temperature_2m': [27], 'weather_code': [1.5]},
    ]) {
      final client = MockClient((_) async => http.Response(
        jsonEncode({'hourly': payload}), 200,
      ));
      expect(
        () => WeatherService(client: client).fetchHourlyRiyadh(),
        throwsA(isA<WeatherServiceException>()),
      );
      client.close();
    }
  });

  test('non-success provider response becomes a service exception', () async {
    final client = MockClient((_) async => http.Response('unavailable', 503));
    expect(
      () => WeatherService(client: client).fetchRiyadh(),
      throwsA(isA<WeatherServiceException>()),
    );
    client.close();
  });

  test('malformed hourly response is rejected', () async {
    final client = MockClient((_) async => http.Response(
      jsonEncode({'hourly': {'time': ['2026-11-03T10:00'], 'temperature_2m': [], 'weather_code': [0]}}),
      200,
    ));
    expect(
      () => WeatherService(client: client).fetchHourlyRiyadh(),
      throwsA(isA<WeatherServiceException>()),
    );
    client.close();
  });
}
